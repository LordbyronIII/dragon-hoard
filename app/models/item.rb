class Item
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Sequence
  include MafiaConnections

  field :name
  field :description
  field :price,         type: Float,   default: 0.0
  field :quantity,      type: Integer, default: 1
  field :ghost,         type: Boolean, default: false
  field :one_of_a_kind, type: Boolean, default: false
  field :customizable,  type: Boolean, default: false
  field :available,     type: Boolean, default: true
  field :published,     type: Boolean, default: false
  field :discontinued,  type: Boolean, default: false
  field :cloned,        type: Boolean, default: false
  field :in_gallery,    type: Boolean, default: false
  field :cost,          type: Float
  field :metals,        type: Array
  field :finishes,      type: Array
  field :jewels,        type: Array
  field :colors,        type: Array
  field :designer_id
  field :size_range
  field :category
  field :gender
  field :custom_id
  field :old_variation_id

  field :backorder_notes, type: String, default: 'Although this item is currently sold out, we can recast this. Ordering this item will put the job in our work queue and your piece will ship within 4 - 7 weeks after the order has processed.'

  field :customizable_notes
  field :discontinued_notes

  field :pretty_id,         type: Integer
  sequence :pretty_id  

  embeds_many :assets
  embeds_many :variations
  has_and_belongs_to_many :collections

  validates :name, presence: true

  before_save :validate_cost
  before_save :validate_price
  # after_save  :create_variation

  def validate_cost
    self.cost = launder_money(self.cost)
  end

  def validate_price
    self.price = launder_money(self.price)
  end

  def create_variation
    return true if variations.present?
    variations.create
    save
  end

  CATEGORIES = [
    ['Ring', 'ring'],
    ['Necklace', 'necklace'],
    ['Earrings', 'earrings'],
    ['Bracelet', 'bracelet'],
    ['Everything Else', 'everthing else']
  ]

  GENDERS = [
    ['Mens', 'mens'],
    ['Womens', 'womans'],
    ['Unisex', 'unisex']
  ]

  scope :published,     where(published: true)
  scope :unpublished,   where(published: false)
  scope :available,     where(available: true)
  scope :not_available, where(available: false)
  scope :listable,      where(published: true, available: true, ghost: false)
  scope :ooak,          where(one_of_a_kind: true)
  scope :nooak,         where(one_of_a_kind: false)
  scope :in_gallery,    where(in_gallery: true)

  scope :with_color_id, ->(color_id) {
    where('variations.colors._id' => color_id)
  }

  scope :with_color,    ->(color_name) {
    where('variations.colors.names' => Regexp.new(color_name))
  }

  default_scope order_by([:created_at, :desc])

  class << self
  
    def find_variation(variation_id)
      where('variations._id' => variation_id).
      map do|item| 
        item.variations.where(_id: variation_id).first
      end.flatten.first
    end

    def search(query=nil)
      return all if query.empty?

      keywords = query.split(' ')
      ids      = []
      names    = []
      results  = nil
      
      keywords.each do |keyword|
        if keyword.match(/[IDid]+?(\d+)/)
          ids << keyword.match(/[IDid]+?(\d+)/).captures.first.to_i
        else
          names << keyword
        end
      end

      ids.flatten   if ids.present?
      names.flatten if names.present?

      if names.present?
        names = names.join(' ')
        query_hash = [
          {name:                       Regexp.new(names)},
          {name:                       Regexp.new(names.titleize)},
          {name:                       Regexp.new(names.downcase)},
          {name:                       Regexp.new(names.upcase)},
          {description:                Regexp.new(names)},
          {description:                Regexp.new(names.titleize)},
          {description:                Regexp.new(names.downcase)},
          {description:                Regexp.new(names.upcase)},
          {'variations.description' => Regexp.new(names)},
          {'variations.description' => Regexp.new(names.titleize)},
          {'variations.description' => Regexp.new(names.downcase)},
          {'variations.description' => Regexp.new(names.upcase)}
        ]

        results = any_of(query_hash)
      end

      if ids.present?
        ids.each do |item_id|
          query_hash = {pretty_id: [item_id]}
          results.nil? ? results = any_in(query_hash) : results.any_in(query_hash)
        end
      end
      
      return results
    end

    def categories
      CATEGORIES
    end

    def genders
      GENDERS
    end

    def colors
      where(:'variations.colors.names'.exists => true).
      map(&:variations).flatten.
      map(&:colors).flatten.uniq
    end

    def colors_with(color_name)
      colors.
      select do |color|
        color.names =~ Regexp.new(color_name)
      end.flatten.uniq {|color| color.names }
    end

    def colors_from_position(position)
      colors.
      select do |color|
        color.position == position
      end.flatten.uniq
    end

  end

  def designer
    designer_id ? User.find(designer_id) : nil
  end

  def designer=(user)
    self.designer_id = user.id
  end

  def sizes
    available_sizes = []
    if size_range =~ /,/
      available_sizes += split_sizes(size_range)
    elsif size_range =~ /-/
      available_sizes += split_size_range(size_range) # returns an array of size strings
    else
      available_sizes = [size_range]
    end
    return available_sizes.flatten.collect {|size| size.to_f}
  end

  def sizes=(new_size_range)
    self.size_range = new_size_range
  end

  def collections_csv=(csv)
    new_collections = []
    csv.split(',').each do |collection_id|
      new_collections << Collection.find(collection_id) unless new_collections.include?(Collection.find(collection_id))
    end
    self.collections = new_collections
  end

  def collections_csv
    self.collections.collect {|collection| collection.id }.join(",")
  end
  
  def colors_csv
    colors.map(&:position).join(',')
  end

  def colors_csv=(csv)
    self.colors = csv.split(',').sort.map {|position| Item.colors_from_position(position).first}.compact
  end

  def metal_csv
    return '' unless metals
    metals.join(',')
  end

  def metal_csv=(csv)
    self.metals = csv.split(',')
  end

  def finish_csv
    return '' unless finishes
    finishes.join(',')
  end

  def finish_csv=(csv)
    self.finishes = csv.split(',')
  end

  def jewel_csv
    return '' unless jewels
    jewels.join(',')
  end

  def jewel_csv=(csv)
    self.jewels = csv.split(',')
  end

  def update_asset_position(asset, position=nil)
    new_position = position.nil? ? self.assets.count : position.to_i
    
    asset_list = self.assets - [asset]
    asset_list.insert new_position, asset

    asset_list.each_with_index { |saved_asset, index| saved_asset.update_attribute :position, index }

    assets = asset_list
    save
  end

private

  def split_size_range(range)
    return range unless range =~ /-/
    sizes_from_range = []
    start_range, end_range = range.split('-')

    (start_range.to_i..end_range.to_i).each do |size|
      sizes_from_range.push(size.to_s)
      sizes_from_range.push("#{size}.5") unless size == end_range.to_i
    end

    return sizes_from_range
  end

  def split_sizes(sizes_csv)
    return sizes_csv.split(/,/).map {|range| split_size_range(range)}.flatten
  end
    
end
