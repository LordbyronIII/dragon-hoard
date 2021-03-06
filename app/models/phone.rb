class Phone
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Sequence

  field :number

  belongs_to :user

  # validates :number, format: {with: /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[ ]?[-. ]?[ ]?([0-9]{4})$/, message: "%{value} is not a proper phone number. Example: (231)775-1289"}
end

