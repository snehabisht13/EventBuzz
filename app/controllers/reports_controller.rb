class ReportsController < ApplicationController
  include BeforeAction
  before_action :authenticate_user!
  before_action :is_admin

  def index
  end

  def event_reports
    @upcoming_events = Event.where('start_date >= ?', Date.today).order(:start_date)
                      .paginate(page: params[:page], per_page: 3)
    @completed_events = Event.where('start_date < ?', Date.today).order(:start_date)
                        .paginate(page: params[:page], per_page: 3)
  end

  def rsvp_statistics
  @upcoming_events = Event.where('start_date >= ?', Date.today).order(:start_date).paginate(page: params[:page], per_page: 3)
  @completed_events = Event.where('start_date < ?', Date.today).order(:start_date).paginate(page: params[:page], per_page: 3)
  @total_invited = Guest.count
  @accepted = Rsvp.where(status: 'attending').count
  @declined = Rsvp.where(status: 'declined').count
  @pending = Rsvp.where(status: 'pending').count

  total = @total_invited


  @response_rate    = total > 0 ? ((@accepted + @declined) * 100.0 / total).round(1) : 0
  @accepted_percent = total > 0 ? (@accepted * 100.0 / total).round(1) : 0
  @declined_percent = total > 0 ? (@declined * 100 / total) : 0
  @pending_percent  = total > 0 ? (@pending * 100 / total) : 0
  end

  def guest_preferences
    @upcoming_events = Event.where('start_date >= ?', Date.today).order(:start_date)
                        .paginate(page: params[:page], per_page: 3)
    @completed_events = Event.where('start_date < ?', Date.today).order(:start_date)
                        .paginate(page: params[:page], per_page: 3)
  end

  def venue_utilization
    @venues = Venue.includes(:events).all.paginate(page: params[:page], per_page: 2)
  end
end
