class Message < ApplicationRecord
  # Associations
  belongs_to :conversation
  belongs_to :sender, class_name: "User"

  # Validations
  validates :content, presence: true
  validates :sender_role, presence: true, inclusion: { in: %w[initiator expert] }
  validates :is_read, inclusion: { in: [true, false] }

 
end
