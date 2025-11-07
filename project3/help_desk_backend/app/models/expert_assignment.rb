class ExpertAssignment < ApplicationRecord
  # Associations
  belongs_to :conversation
  belongs_to :expert, class_name: "User"

  # Validations
  validates :status, presence: true
  validates :assigned_at, presence: true

end
