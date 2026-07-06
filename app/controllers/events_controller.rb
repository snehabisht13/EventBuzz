
class EventsController < ApplicationController
  include BeforeAction

    before_action :authenticate_user!

    before_action :verify_event_ownership!,  only: [ :edit, :update, :destroy,
    :invite_guests, :send_invites, :send_custom_email ]

    before_action :is_event_manager, except: [ :show, :index ]
    before_action :is_admin, only: [ :index ]

  def new
    @event = Event.new
    @venues = Venue.all
  end

  def create
    @event = Event.new(event_params)
    if @event.save
      redirect_to index_event_manager_path, notice: 'Created Successfully'
    else
      render :new, alert: "Failed to create event", status: :unprocessable_entity
    end
  end

  def index
    @events = Event.all.order(Arel.sql('start_date < current_date, start_date ASC')).includes(:event_manager)
    .paginate(page: params[:page], per_page: 2)
  end

  def show
    @event = Event.find(params[:id])
    @activities = Activity.where(event_id: @event).includes(:user)
  end

  def edit
    @event =  Event.find(params[:id])
  end

  def update
    @event = Event.find(params[:id])

    if @event.update(event_params)
      redirect_to event_path(@event), notice: 'Event updated successfully!'
    else
      render :edit, alert: 'Failed to update event', status: :unprocessable_entity
    end
  end

  def destroy
    @event = Event.find(params[:id])
    if @event.destroy
      redirect_to events_path, notice: 'Event deleted.'
    else
      redirect_to event_path(@event), alert: 'Could not delete event.'
    end
  end


  # email invite to guests

  def invite_guests
    @event = Event.find(params[:event_id])
  end

  def send_invites
  @event = Event.find(params[:id])

  if params[:emails].present? && params[:excel_file].present?
    redirect_to invite_guests_event_path(@event), alert: 'Please use only one option'
  end

  if params[:emails].blank? && params[:excel_file].blank?
    redirect_to invite_guests_event_path(@event), alert: 'Please use only one option'
  end

  emails = []

  # mannual email
  if params[:emails].present?
    emails = params[:emails].split(',').map(&:strip)
    # invalid = emails.reject { |e| e.strip.match?(/\A[a-zA-Z0-9._%+-]+@gmail\.com\z/) }
    invalid = emails.reject { |e| e.match?(URI::MailTo::EMAIL_REGEXP) }

    if invalid.any?
    flash[:alert] = "Invalid emails: #{invalid.join(', ')}"
    redirect_back(fallback_location: root_path)
    return
    end
  end

  # excel
  if params[:excel_file].present?
  file = params[:excel_file]

  extension = File.extname(file.original_filename).downcase
  allowed_extensions = [ '.xlsx', '.xls', '.csv' ]

  unless allowed_extensions.include?(extension)
    redirect_to event_invite_guests_path(@event),
      alert: 'Only Excel files (.xlsx, .xls, .csv) are allowed' and return
  end

  sheet = Roo::Spreadsheet.open(file.path, extension: extension.delete('.').to_sym)

  header = sheet.row(1).map { |h| h.to_s.downcase.strip }
  email_index = header.index('email')

  if email_index.nil?
    redirect_to invite_guests_event_path(@event),
      alert: "Excel must contain 'email' column" and return
  end

  (2..sheet.last_row).each do |i|
    email = sheet.row(i)[email_index]
    emails << email.to_s.strip if email.present?
  end
  end

  # Remove duplicates
  emails = emails.map(&:downcase).uniq

  emails.each do |email|
    # Avoid duplicate guest
    guest = Guest.create_or_find_by(email: email, event_id: @event.id)

    user = User.find_by(email: email)

    if user
      guest.update(user_id: user.id)
      Rsvp.find_or_create_by(
        user_id: user.id,
        event_id: @event.id
      ) do |r|
        r.status = 'pending'
      end
    end

    # Send email
    GuestMailer.invite_email(email.strip, @event).deliver_later
  end

  redirect_to rsvp_invites_path(@event), notice: 'Invitations sent!'
end


  # send custom email to guests
  def send_custom_email
  @event = Event.find(params[:id])

  subject = params[:subject]
  message = params[:message]

  guests = []

  case params[:target]
  when 'all'
    guests = @event.guests

  when 'pending'
    guests = @event.guests.joins(user: :rsvps)
                 .where(rsvps: { status: 'pending' })

  when 'attending'
    guests = @event.guests.joins(user: :rsvps)
                 .where(rsvps: { status: 'attending' })

  when 'individual'
    guests = @event.guests.where(id: params[:guest_ids])
  end

  guests.each do |guest|
    EventMailer.custom_email(guest, subject, message, @event).deliver_later
  end

  redirect_to event_rsvps_path(@event), notice: 'Emails sent!'
end


  private
  def event_params
    params.require(:event).permit(:name,
    :description,
    :start_date,
    :end_date,
    :event_manager_id,
    :venue_id,
    :capacity)
  end


  def verify_event_ownership!
  event_id = params[:id] || params[:event_id]
  @event = Event.find(event_id)
  return if current_user.admin?
    unless @event.event_manager_id == current_user.id
    redirect_to root_path, alert: 'Access denied'
    end
  end
end
