lib_path = File.expand_path('../../lib', __FILE__)
$:.unshift(lib_path)
require 'sinatra'
require File.expand_path('../monkey_service',  __FILE__)

get '/' do
  status 405
  'post me'
end

post '/monkey' do
  begin
    status 200
    MonkeyService.handle(request.body.read)
  rescue Exception => e
    status 500
    Hessian2::Writer.write_fault(e)
  end
end
