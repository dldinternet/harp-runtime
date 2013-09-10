# -*- coding: utf-8 -*-
# gems
require 'rubygems'
require 'bundler'

Bundler.require

if ENV['RACK_ENV'] == 'production'
  # production config / requires
else
  # development or testing only
  require 'pry'
  use Rack::ShowExceptions
end

# require the dependencies
$LOAD_PATH.unshift(File.dirname(__FILE__))
require File.join(File.dirname(__FILE__), 'app', 'init')
require 'app/root'
require 'app/api_base'
require 'app/harp_api'

# Following are Swagger directives, for REST API documentation.
##~ sapi = source2swagger.namespace("harp-runtime")
##~ sapi.swaggerVersion = "1.2"
##~ sapi.apiVersion = "1.0.0"
##~ auth = sapi.authorizations.add :apiKey => { :type => "apiKey", :passAs => "header" }

#
# Harp API
#
##~ a = sapi.apis.add
##
##~ a.set :path => "/harp.{format}", :format => "json"
##~ a.description = "Harp runtime invocation"
map "/api/v1/harp" do
  run HarpApiApp
end

map '/' do
  run RootApp
end