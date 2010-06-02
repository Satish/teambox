class UploadsController < ApplicationController
  before_filter :find_upload, :only => [:destroy,:update,:thumbnail,:show]
  skip_before_filter :load_project, :only => [:download]
  before_filter :set_page_title
  
  SEND_FILE_METHOD = :default

  def download
    head(:not_found) and return if (upload = Upload.find_by_id(params[:id])).nil?
    head(:forbidden) and return unless upload.downloadable?(current_user)

    path = upload.asset.path(params[:style])
    unless File.exist?(path) && params[:filename].to_s == upload.asset_file_name
      head(:bad_request)
      raise "Unable to download file"
    end  

    mime_type = File.mime_type?(upload.asset_file_name)

    mime_type = 'application/octet-stream' if mime_type == 'unknown/unknown'

    send_file_options = { :type => mime_type }
    
    case SEND_FILE_METHOD
      when :apache then send_file_options[:x_sendfile] = true
      when :nginx then head(:x_accel_redirect => path.gsub(Rails.root, ''), :content_type => send_file_options[:type]) and return
    end

    send_file(path, send_file_options)
  end
  
  def index
    @uploads = @current_project.uploads
    @upload  = @current_project.uploads.new

    respond_to do |format|
      format.html
      format.xml  { render :xml     => @uploads.to_xml({:root => 'files'}) }
      format.json { render :as_json => @uploads.to_xml({:root => 'files'}) }
      format.yaml { render :as_yaml => @uploads.to_xml({:root => 'files'}) }
    end
  end
  
  def new
    @upload = @current_project.uploads.new(:user => current_user)
  end  
  
  def create
    @upload = @current_project.uploads.new(params[:upload])
    @upload.user = current_user
    @upload.page = @page
    calculate_position if @page

    if is_iframe? # uploads attached to a comment
      @upload.save
      save_slot(@upload) if !@upload.new_record? and @page
      @comment = load_comment unless @page
      @upload.reload
      respond_to do |f|
        f.html { render :template => @page.nil? ? 'uploads/create' : 'uploads/create_page', :layout => 'upload_iframe' }
      end
    else
      respond_to do |f|          
        if @upload.save
          @current_project.log_activity(@upload,'create')
          save_slot(@upload) if @page
          f.html { redirect_to(project_uploads_path(@current_project)) }
        else
          @uploads = @current_project.uploads
          f.html { render :index } 
        end   
      end
    end
  end

  def update
    @upload.update_attributes(params[:upload])

    respond_to do |format|
      format.js
      format.html { redirect_to project_uploads_path(@current_project) }
    end
  end

  def destroy
    if @upload.editable?(current_user)
      @upload.try(:destroy)

      respond_to do |f|
        f.js
        f.html do
          flash[:success] = t('deleted.upload', :name => @upload.to_s)
          redirect_to project_uploads_path(@current_project)
        end
      end
    else
      respond_to do |f|
        error_message = "You are not allowed to do that!"
        f.js   { render :text => "alert('#{error_message}')" }
        f.html { render :text => "alert('#{error_message}')" }
      end
    end
  end
  
  private
    
    def find_upload
      if params[:id].match /^\d+$/
        @upload = @current_project.uploads.find(params[:id])
      else
        @upload = @current_project.uploads.find_by_asset_file_name(params[:id])
      end
    end

end