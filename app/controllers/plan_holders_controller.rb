class PlanHoldersController < ApplicationController
  before_filter :find_project, only: [:create]

  def create
    @planholder = PlanHolder.new(planholders_params)

    begin
      @filenames = @project.documents.collect { |doc| doc.document.url }
      @zipfile_name = "#{ Rails.root }/tmp/#{ @project.name_with_project_number }-#{ Time.now.to_i }.zip_#{ Process.pid }"
    rescue DropboxError
      puts "***Storage error: looks like the necessary documents are not where they're supposed to be!"
    end

    respond_to do |wants|
      if @planholder.save
        wants.html do
          if @filenames && !@filenames.empty?
            Zip::File.open(@zipfile_name, Zip::File::CREATE) do |zipfile|
              @filenames.each_with_index do |filename, index|
                original_filename = filename.split('/').last
                doc = Document.where(document_file_name: original_filename).first

                if doc
                  destination = File.join(Rails.root, "tmp/#{ original_filename }_#{ Process.pid }")
                  doc.document.copy_to_local_file(destination)
                  zipfile.add(original_filename, destination)
                end
              end
            end

            @mixpanel.track('1', 'planholder-download')
            send_file @zipfile_name, filename: "#{ @project.name_with_project_number }-#{ Time.now.to_i }.zip"
          else
            wants.html { redirect_to new_plan_holder_url }
            wants.json { head :unprocessable_entity }
          end
        end
      else
        wants.html { render action: 'new' }
      end
    end
  end

  def new
    @planholder = PlanHolder.new
    @planholder.user = User.new
    @planholder.company = Company.new
    @projects = Project.order('project_number ASC').pluck(:id, :name, :project_number)
  end

  def edit
  end

  def update
  end

  def show
  end

  def index
  end

  def destroy
  end

  def update_interface
    @project = Project.find(params[:plan_holder][:project_id])
    @mixpanel.track('1', 'bid-docs-selected')

    respond_to do |wants|
      wants.json { render json: @project, status: :ok }
    end
  end

  private
  def find_project
    @project = Project.find(params[:plan_holder][:project_id])
  end

  def planholders_params
    params.require(:plan_holder).permit(:project_id, company_attributes: [:name], user_attributes: [:email, :first_name, :last_name])
  end
end
