class RappelsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :find_rappel, only: [:edit, :update, :destroy]
  before_action :authorize

  def index
    @rappels = Rappel.where(project_id: @project.id)
                     .order(created_at: :desc)
  end

  def new
    @rappel = Rappel.new(project_id: @project.id)
    @issues = @project.issues.open
  end

  def create
    @rappel = Rappel.new(rappel_params)
    @rappel.project = @project
    @rappel.next_run_date = Time.now

    if @rappel.save
      flash[:notice] = l(:notice_rappel_created)
      redirect_to project_rappels_path(@project)
    else
      @issues = @project.issues.open
      render :new
    end
  end

  def edit
    @issues = @project.issues.open
  end

  def update
    if @rappel.update(rappel_params)
      flash[:notice] = l(:notice_rappel_updated)
      redirect_to project_rappels_path(@project)
    else
      @issues = @project.issues.open
      render :edit
    end
  end

  def destroy
    @rappel.destroy
    flash[:notice] = l(:notice_rappel_deleted)
    redirect_to project_rappels_path(@project)
  end

  private

  def find_rappel
    @rappel = Rappel.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def rappel_params
    params.require(:rappel).permit(:subject, :message, :issue_id, :frequency_unit, :frequency_value)
  end
end 