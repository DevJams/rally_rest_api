class TimeoutCatchingRestBuilder < RestBuilder # :nodoc all
  def send_request(url, req, username, password)
    begin
      super
    rescue Timeout::Error, Errno::ETIMEDOUT => e
      @logger.warn "Caught Timeout Exception. Trying again..."
      retry
    end
  end
end
