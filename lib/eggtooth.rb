# A Sling-like framework for Ruby. The root module itself just contains helper methods.
# All the good stuff is deeper in.
module Eggtooth
	PATH_INSTALL = File.dirname(File.dirname(__FILE__))

	# Given a path and its parent, return a full path relative to the parent,
	# or the given path if it starts with '/'.
	def self.resolve_path(path, parent)
		return path if path[0] == '/'
		if path[0..1] == './'
			# remove leading ./
			path = path[2..-1]
		elsif path[0..2] == '../'
			# remove leading ../
			levels = path.split('../')
			while levels.length > 1
				parent = File.dirname(parent)
				levels.shift
			end
			path = levels[0]
		end

		path = "#{parent}/#{path}"
	end

 	# Quick way to cast a `nil` value into a default value. Some notes on the default:
	# 
	# # If value is `nil` and `default` is a class, `default` [*must*] have a 0-argument constructor.
	# # If value is scalar and `default` is a {{Array}}, value is converted to an array.
	#
	# @param default Object A concrete instance or a class that accepts a 0-argument constructor.
	def self.get_value(val, default)
		if !val
			if default.is_a?(Class)
				val = default.new
			else
				val = default
			end
		elsif (default.is_a?(Array) || default == Array) && !val.is_a?(Array)
			val = [val]
		end
		val
	end

	# Compares a scalar value to a scalar or array reference.	
	def self.equal_mixed(needle, haystack)
		if !haystack.is_a?(Array)
			return needle == haystack
		else
			return haystack.find_index(needle) != nil
		end
	end
end

class Hash
	def symbolize_keys
		queue = {}
		each do |key, val|
			if !key.is_a?(Symbol)
				queue[key.to_sym] = self.delete(key)
			end
		end
		queue.each do |key, val|
			self[key] = val
		end
	end
end

class Array
	def symbolize_vals
		each_index do |i|
			if !self[i].is_a?(Symbol)
				self[i] = self[i].to_sym
			end
		end
	end
end

require 'eggshell'
require 'rack'
require 'json'
require 'yaml'

require_relative './eggtooth/framework.rb'
require_relative './eggtooth/service-manager.rb'
require_relative './eggtooth/config-helper.rb'
require_relative './eggtooth/resource-manager.rb'

require_relative './eggtooth/client.rb'
require_relative './eggtooth/dispatcher.rb'
require_relative './eggtooth/action-manager.rb'
require_relative './eggtooth/action-manager/script-action.rb'

#require_relative './eggtooth/eggshell-bundle.rb'
#require_relative './eggtooth/filter-manager.rb'