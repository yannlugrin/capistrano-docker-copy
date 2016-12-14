require 'capistrano/scm/plugin'

module Capistrano
  class DockerCopy < Capistrano::SCM::Plugin
    VERSION = '0.1.0'
  end
end
