require 'webrick'
require 'json'
 
include WEBrick
 
def start_webrick(config = {})
  config.update(:Port => 9955)    
  server = HTTPServer.new(config)
  yield server if block_given?
  ['INT', 'TERM'].each {|signal|
    trap(signal) {server.shutdown}
  }
  server.start
end
 
class RestServlet < HTTPServlet::AbstractServlet
  def do_GET(req,resp)
      # Split the path into pieces, getting rid of the first slash
      path = req.path[1..-1].split('/')
      raise HTTPStatus::NotFound if !RestServiceModule.const_defined?(path[0])
      response_class = RestServiceModule.const_get(path[0])
       
      if response_class and response_class.is_a?(Class)
        # There was a method given
        if path[1]
          response_method = path[1].to_sym
          # Make sure the method exists in the class
          raise HTTPStatus::NotFound if !response_class.respond_to?(response_method)
          # Remaining path segments get passed in as arguments to the method
          if path.length > 2
            resp.body = response_class.send(response_method, path[2..-1])
          else
            resp.body = response_class.send(response_method)
          end
          raise HTTPStatus::OK
        # No method was given, so check for an "index" method instead
        else
          raise HTTPStatus::NotFound if !response_class.respond_to?(:index)
          resp.body = response_class.send(:index)
          raise HTTPStatus::OK
        end
      else
        raise HTTPStatus::NotFound
      end
  end
end
 
module RestServiceModule
  class HelloService
    def self.index()
      return JSON.generate({:data => 'Hello World'})
    end
 
    def self.greet(args)
      return JSON.generate({:data => "Hello #{args.join(' ')}"})
    end
  end
end
 
start_webrick { | server |
  server.mount('/', RestServlet)
}
