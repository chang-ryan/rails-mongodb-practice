class Place
  attr_accessor :id, :formatted_address, :location, :address_components

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    self.mongo_client[:places]
  end

  def self.load_all(f)
    array = JSON.parse(f.read)
    collection.insert_many(array)
  end

  def initialize(params={})
    @id = params[:_id].to_s
    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:geolocation || :location])

    @address_components = []
    if !params[:address_components].nil?
      params[:address_components].each do |address_component|
        @address_components << AddressComponent.new(address_component)
      end
    end
  end

  def self.find_by_short_name(s)
    result = collection.find("address_components.short_name": s)
    result.nil? ? nil : result
  end

  def self.to_places(view)
    places = []
    view.each { |doc| places << Place.new(doc) }
    places
  end

  def self.find(id)
    id = BSON::ObjectId.from_string(id) unless id === BSON::ObjectId
    result = collection.find(:_id => id).first
    result.nil? ? nil : Place.new(result)
  end

  def self.all(offset=0, limit=nil)
    result = collection.find().skip(offset)
    result = result.limit(limit) if !limit.nil?

    result.map { |doc| Place.new(doc) }
  end

  def destroy
    self.class.collection.find(:_id => BSON::ObjectId.from_string(self.id)).delete_one
  end

  def self.get_address_components(sort={:_id => 1}, offset=0, limit=9999)
    result = collection.find().aggregate([{:$project => {:_id=>1, :address_components=>1, :formatted_address=>1, "geometry.geolocation"=>1}}, {:$unwind => '$address_components'},  {:$sort => sort}, {:$skip => offset}, {:$limit => limit}])
  end

  def self.get_country_names
    result = collection.find().aggregate([
      {:$unwind  => "$address_components"},
      {:$project => {:_id => 0, :address_components=> {:long_name => 1, :types => 1}}},
      {:$match   => {"address_components.types" => "country"}},
      {:$group   => {:_id => "$address_components.long_name"}}
    ]).to_a.map { |h| h[:_id]}
  end

  def self.find_ids_by_country_code(s)
    result = collection.find().aggregate([
      {:$match => {"address_components.short_name" => s}},
      {:$project => {:_id => 1}}
    ]).to_a.map { |h| h[:_id].to_s }
  end

  def self.create_indexes
    collection.indexes.create_one({"geometry.geolocation" => Mongo::Index::GEO2DSPHERE})
  end

  def self.remove_indexes
    collection.indexes.drop_all()
  end

  def self.near(point, max_distance=nil)
    point = point.to_hash
    collection.find(
      "geometry.geolocation" => {
        :$near => {
          :$geometry    => point,
          :$maxDistance => max_distance
        }
      }
    )
  end

  def near(max_distance=nil)
    point = self.location.to_hash
    result = self.class.collection.find(
      "geometry.geolocation" => {
        :$near => {
          :$geometry =>    point,
          :$maxDistance => max_distance
        }
      }
    ).map { |doc| Place.new(doc) }
  end
end
