require 'rubygems'

require 'base64'
require 'cgi'
require 'digest/sha2'
require 'logger'
require 'net/http'
require 'net/https'
require 'rest-client'
require 'rexml/document'
require 'thread'

module Ooyala
  module API

    class Client
      attr_reader :partner, :ingestion
      def initialize(partner_code, secret_code, default_expires=15, logger=Logger.new(STDERR))
        @partner = Partner.new(partner_code, secret_code, default_expires, logger)
        @ingestion = Ingestion.new(partner_code, secret_code, default_expires, logger)
      end
    end


    class Base
      def initialize(partner_code, secret_code, default_expires=15, logger=Logger.new(STDERR))
        @partner_code = partner_code
        @secret_code = secret_code
        @default_expires = default_expires
        @logger = logger
      end

      private

      def signed_params(params, post_data='')
        params = {
          'pcode' => @partner_code,
          'expires' => Time.now.gmtime.to_i + @default_expires,
        }.merge(params)
        
        string_to_sign = @secret_code
        param_string = ''

        params.keys.sort{ |a,b| a.to_s <=> b.to_s }.each do |key|
          string_to_sign += "#{key}=#{params[key]}" if key != 'pcode'
          param_string += "&#{CGI.escape(key.to_s)}=#{CGI.escape(params[key].to_s)}"
        end

        string_to_sign += post_data
        
        digest = Digest::SHA256.digest(string_to_sign)
        signature = Base64::encode64(digest).chomp.gsub(/=+$/, '')
        
        param_string += "&signature=#{CGI.escape(signature)}"

        return param_string.sub(/^&/, '')
      end

      def create_http
        http = Net::HTTP::new('api.ooyala.com', 443)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.use_ssl = true
        return http
      end

      def get(path, params, headers={})
        http = create_http()
        url = path + '?' + signed_params(params)
        
        STDERR.puts url
        
        @logger.info "Calling API: #{url}"
        response, body = http.get(url, headers)
        return body
      end
      
      def post(path, params, post_data, headers={})
        http = create_http()
        response,    = http.post(path + '?' + signed_params(params, post_data), 
                                   post_data,
                                   headers)
        return body
      end
    end


    class Partner < Ooyala::API::Base
      def query(params)
        return get('/partner/query', params)
      end
      
      def thumbnails(params)
        return get('/partner/thumbnails', params)
      end

      def edit(params)
        return get('/partner/edit', params)
      end

      def labels(params)
        return get('/partner/labels', params)
      end

      def set_metadata(params)
        return get('/partner/set_metadata', params)
      end

      def metadata(params)
        return get('/partner/metadata', params)
      end

      def channels(params)
        return get('/partner/channels', params)
      end
      
      def assign_ads(params, post_data)
        return post('/partner/ads',
                    (params || {}).merge({ :mode => 'assign' }),
                    post_data,
                    { 'Content-Type' => 'application/xml' })
      end
    end
    
    
    class Ingestion < Ooyala::API::Base
      def upload_video(file_path, original_file_name=nil, title=nil, chunk_size=2**22, num_threads=10, uploaded_by_client='', &callback)
        start_time = Time.now
        size = File.size(file_path)
        original_file_name ||= File.basename(file_path)
        title ||= original_file_name
        embed_code, urls = create_video({ :file_name => original_file_name,
                                          :title => title,
                                          :file_size => size,
                                          :chunk_size => chunk_size,
                                          :uploaded_by_client => uploaded_by_client })
        callback.call(embed_code) if not callback.nil?
        file = File.open(file_path)

        # Thread uploads
        thread_pool = []
        num_threads.times do  # We'll do up to 10 concurrent upload threads
          thread_pool << Thread.new do
            while true
              url = bytes = nil
              # Here we need thread exclusivity to get the appropriate url and bytes from the file
              Thread.exclusive do
                url = urls.shift
                bytes = file.read(chunk_size) if url
              end
              break if url.nil?  # We're done

              success = true
              uri = URI.parse(url)
              10.times do |i|  # Try up to 3 times to upload
                begin
                  http = Net::HTTP::new(uri.host, uri.port)
                  http.use_ssl = true if uri.scheme == 'https'
                  response, body = http.put(uri.request_uri, bytes)
                  break if (success = response.is_a?(Net::HTTPNoContent))
                  @logger.error "Error uploading #{uri}:\n#{body}"
                rescue Timeout::Error
                  @logger.error "Timeout uploading #{uri}"
                end
              end
              raise Exception.new("Error uploading #{uri}") if !success
            end
          end
        end
        thread_pool.each { |thread| thread.join(60*60*3) }

        upload_complete({ :embed_code => embed_code })

        run_time = Time.now - start_time
        @logger.info "Uploaded #{size} bytes in #{run_time} seconds (#{size * 8 / 1024 / 1024 / run_time} Mbps)."

        return embed_code

      ensure
        file.close if file
      end

      def create_video(params)
        result = get('/ingestion/create_video', params)
        doc = REXML::Document.new(result)
        video = doc.elements['video']
        embed_code = video.elements['embedCode'].text.strip
        upload_urls = video.elements.collect('urls/url') { |e| e.text.strip }
        return embed_code, upload_urls
      end

      def upload_complete(params)
        return get('/ingestion/upload_complete', params)
      end

      def upload_preview(embed_code, file_name)
        file = File.open(file_name)
        url = 'http://uploader.ooyala.com/api/upload/preview?' + signed_params({ :embed_code => embed_code })
        @logger.debug url
        begin
          res = RestClient.post(url, :file => File.new(file_name))
          return res
        rescue => e
          puts "Error uploading preview for #{embed_code} with file : #{file_name}. Error #{e}" 
        end
      ensure
        file.close if file
      end

      def create_remote_asset(params)
        return get('/ingestion/create_remote_asset', params)
      end
    end
  end
end
