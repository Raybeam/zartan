class StaticListController < ApplicationController
  before_filter :assign_source

  def show
    @unhealthy_proxies = unhealthy_proxies
  end

  def cleanup
    unhealthy_proxies.each do |proxy|
      proxy.destroy
    end
    flash[:info] = "All unhealthy proxies have been cleared."
    redirect_to action: :show
  end

  def refresh
    proxy_list = unhealthy_proxies.to_a
    proxy_list.each do |proxy|
      proxy.proxy_performances.clear
      proxy.deleted_at = nil
      proxy.save
    end
    Site.all.each do |site|
      site.add_proxies(*proxy_list)
    end
    flash[:info] = "All previously unhealthy proxies have been refreshed and added back to the proxy pool."
    redirect_to action: :show
  end

  def append
    new_proxy_list = params[:new_proxy_list]
    errors = []
    proxies_added = []

    # Iterate through the lines of the proxy list
    new_proxy_list.each_line do |proxy_spec|
      proxy_spec.strip!
      next if proxy_spec.empty? or proxy_spec =~ /^#/

      # Extract the username, password, host, and port from each line
      host, port, username, password = nil, nil, nil, nil
      case proxy_spec
      when /^(.+):(.+)@([0-9.]+):([0-9]+)$/
        host = $3
        port = $4.to_i
        username = $1
        password = $2
      when /^([0-9.]+):([0-9]+)$/
        host = $1
        port = $2.to_i
      else
        errors << "Invalid proxy specification: #{proxy_spec}"
        next
      end

      # Create the new proxy if it doesn't already exist
      if @source.proxies.active.where(host: host, port: port).count > 0
        errors << "Proxy #{proxy_spec} already exists."
      else
        @source.add_proxy(host, port, username, password)
        proxies_added << @source.proxies.where(host: host, port: port).first
      end
    end

    # Add all of the new proxies to each site
    Site.all.each do |site|
      site.add_proxies(*proxies_added)
    end

    # Report all errors, if any
    unless errors.empty?
      flash[:error] = errors
    end

    flash[:info] = "#{proxies_added.count} new proxies added."

    redirect_to action: :show
  end

  private
  def assign_source
    @source = Source.find(params[:source_id])
    unless @source and @source.is_a? Sources::Static
      flash[:error] = "Unhealthy proxy management is only available for static sources."
      redirect_to source_path(@source)
    end
  end

  def unhealthy_proxies
    @source.proxies.where('deleted_at IS NOT NULL')
  end
end
