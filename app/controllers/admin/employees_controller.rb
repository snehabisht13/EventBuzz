class Admin::EmployeesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def new
    @user = User.new
  end

  

  def create
    @user = User.new(user_params)

    if @user.save
      token = @user.send_reset_password_instructions
      EmployeeMailer.with(user: @user, token: token).welcome_email.deliver_later

      redirect_to admin_dashboard_path, notice: 'Employee invited. They will set their own password.'
    else
      render :new
    end
  end

  def showEventManagers
    @event_managers = User.where(role: 'event_manager')
  end

  def showActivityOwners
    @activity_owners = User.where(role: 'activity_owner')
  end

  def show
  @user = User.find(params[:id])

  if @user.role == 'event_manager'
    @events = Event.where(event_manager_id: @user.id).includes(:venue)

  elsif @user.role == 'activity_owner'
    @events = Event.joins(:activities)
                   .where(activities: { user_id: @user.id })
                   .includes(:venue)
                   .distinct

  else
    @events = []
  end
end


  def destroy
  end


  private
  def user_params
    params.require(:user).permit(:name, :email, :role)
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: 'Access denied.'
    end
  end
end
