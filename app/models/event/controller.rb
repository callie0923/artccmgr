class Event
  class Controller < ApplicationRecord
    belongs_to :event
    belongs_to :position
    belongs_to :user, optional: true

    validates :event, presence: true, allow_blank: false
    validates :position, presence: true, allow_blank: false
    validates :user, uniqueness: { scope: :event, message: 'already signed up' }

    validate :not_a_pilot

    private

    # Validates the user signing up for a controller position is not
    # an event pilot
    def not_a_pilot
      unless event.nil?
        errors[:user] << 'already pilot in this event' unless event.pilots.find_by(user: user).nil?
      end
    end
  end
end
