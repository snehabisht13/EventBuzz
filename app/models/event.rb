class Event < ApplicationRecord
  belongs_to :event_manager, class_name: 'User', optional: true
  belongs_to :venue
  has_many :activities, dependent: :destroy
  has_many :guests, dependent: :destroy
  has_many :rsvps, dependent: :destroy
  has_many :queries, dependent: :destroy


  validates :start_date, presence: true
  validates :capacity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :capacity_cannot_exceed_venue_capacity

  def total_invited
    guests_count || 0
  end

  def rsvp_stats
    @rsvp_stats ||= rsvps.group(:status).count
  end

  def accepted_count
    rsvp_stats[Rsvp.statuses[:attending]].to_i
  end

  def declined_count
    rsvp_stats[Rsvp.statuses[:declined]].to_i
  end

  def pending_count
    rsvp_stats[Rsvp.statuses[:pending]].to_i
  end


  def capacity_cannot_exceed_venue_capacity
  return if capacity.blank? || venue.blank?

  if capacity > venue.capacity
    errors.add(:capacity, "cannot exceed venue capacity (#{venue.capacity})")
  end
  end
end
