class Place
  include Mongoid::Document
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
end
