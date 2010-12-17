module APNS
  require 'socket'
  require 'openssl'
  require 'json'
  
  class PemPathError < RuntimeError;end
  class PemFileError < RuntimeError;end

  ## Host for push notification service
  # production: gateway.push.apple.com
  # development: gateway.sandbox.apple.com
  ## Host for feedback service
  # production: feedback.push.apple.com
  # development: feedback.sandbox.apple.com
  @host = 'gateway.sandbox.push.apple.com'
  @port = 2195
  
  @feedback_port = 2196
  
  # openssl pkcs12 -in mycert.p12 -out client-cert.pem -nodes -clcerts
  @pem = nil # this should be the path of the pem file not the contents
  @pass = nil
  
  # Persistent connection
  @@ssl = nil
  @@sock = nil
    
  class << self
    attr_accessor :host, :pem, :port, :pass
  end 
  
  # send one or many payloads
  #
  # Connection
  #   The connection is made only if needed and is persisted until it times out or is closed by the system
  #
  # Errors
  #   If an error occures during the write operation, after 3 retries, the socket and ssl connections are closed and an exception is raised
  #
  # Example:
  #
  #  single payload
  # payload = APNS::Payload.new(device_token, 'Hello iPhone!')
  # APNS.send_payloads(payload)
  #
  #  or with multiple payloads
  # APNS.send_payloads([payload1, payload2])

  def self.send_payloads(payloads)
    # accept Array or single payload
    payloads = payloads.is_a?(Array) ? payloads : [payloads]
    
    return if (payloads.nil? || payloads.count == 0)
    
    # try to connect
    if @@ssl.nil?
      @@sock, @@ssl = self.push_connection
    end
    
    # retain valid payloads only
    payloads.reject!{ |p| !(p.is_a?(APNS::Payload) && p.valid?) }
            
    # loop 
    payloads.each do |payload|
      retry_delay = 2
      begin
        if @@ssl.nil?
          @@sock, @@ssl = self.push_connection
        end
        @@ssl.write(payload.to_ssl); @@ssl.flush
      rescue
        @@ssl.close; @@sock.close
        @@ssl = nil; @@sock = nil
        
        retry_delay *= 2
        if retry_delay <= 8
          sleep retry_delay
          retry
        else
          raise
        end
      end # begin block 
            
    end # each payloads
  end
  
    
  def self.feedback
    sock, ssl = self.feedback_connection
    
    apns_feedback = []
    
    while line = sock.gets   # Read lines from the socket
      line.strip!
      f = line.unpack('N1n1H140')
      apns_feedback << [Time.at(f[0]), f[2]]
    end
    
    ssl.close
    sock.close
    
    return apns_feedback
  end
    
  
  protected
    
  def self.push_connection
    raise PemPathError, "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless self.pem
    raise PemFileError, "The path to your pem file does not exist!" unless File.exist?(self.pem)
    
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(self.pem))
    context.key  = OpenSSL::PKey::RSA.new(File.read(self.pem), self.pass)

    sock         = TCPSocket.new(self.host, self.port)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock,context)
    ssl.connect

    return sock, ssl
  end
  
  def self.feedback_connection
    raise PemPathError, "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless self.pem
    raise PemFileError, "The path to your pem file does not exist!" unless File.exist?(self.pem)
    
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(self.pem))
    context.key  = OpenSSL::PKey::RSA.new(File.read(self.pem), self.pass)

    fhost = self.host.gsub('gateway','feedback')
    
    sock         = TCPSocket.new(fhost, self.feedback_port)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock,context)
    ssl.connect

    return sock, ssl
  end
  
end
