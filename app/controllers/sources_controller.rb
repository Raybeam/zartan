class SourcesController < ApplicationController
  before_filter :assign_source, only: %i(edit update show clear_errors)
  
  def index
  end
  
  def new
    @source = Source.new
    @source.config = {}
    @source_types = valid_source_types
  end
  
  def create
    source_class = Source
    begin
      source_class = params[:source_type].constantize
    rescue
      flash.now[:error] = "Please select a source type"
    end
    
    @source = source_class.new(base_parameters)
    @source.config = config_parameters
    
    if source_class != Source and @source.valid?
      @source.save!
      redirect_to source_path(@source)
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    @source.assign_attributes(base_parameters)
    source_config = @source.config
    config_patch = config_parameters
    
    # Update each config field only if either:
    #   - It's not a password field
    #   - It's a password field, and the user supplied a new value
    @source.class.required_fields.each_pair do |name, type|
      name = name.to_s
      if type == :password
        source_config[name] = config_patch[name] unless config_patch[name].empty?
      else
        source_config[name] = config_patch[name]
      end
    end
    @source.config = source_config
    
    if @source.valid?
      @source.save!
      redirect_to source_path(@source)
    else
      render :edit
    end
  end
  
  def show
  end
  
  def clear_errors
    @source.persistent_errors.clear
    redirect_to source_path(@source)
  end
  
  private
  def assign_source
    @source = Source.find(params[:id])
  end
  
  def base_parameters
    params.require(:source).permit(:name, :max_proxies, :reliability)
  end
  
  def config_parameters
    params.require(:config).to_unsafe_h rescue {}
  end
  
  def valid_source_types
    [
      Sources::DigitalOcean
    ]
  end
end
