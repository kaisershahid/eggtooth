# High-level interfaces for controlling access to various portions of the framework.
# 
# Access control is based on path, which allows protection to real as well as virtual
# resources. The hierarchy of 
module Eggtooth::AccessControl
	module AccessManager
		def authorize(id, password)
		end

		def domains
		end

		def entity_exists?(type, id)
		end

		# 
		def policy_manager
		end
	end

	# Root interface for an authorizable entity. Entities are:
	#
	# - domain
	# - group
	# - user
	#
	# Domains cover a set of users and groups (e.g. a company, or a department within
	# a company). Groups define general set of roles (which can inherit from other groups).
	# Users are entities that directly interact with the framework.
	module Authorizable
		TYPE_DOMAIN = :domain
		TYPE_GROUP = :group
		TYPE_USER = :user

		def id
		end

		def type
		end

		def has_rights?(path, rights)
		end

		def rights(path)
		end

		module Domain
			def groups
			end
			
			def users
			end
		end
		
		module Group
			def users
			end
			
			def member_of(deep = false)
			end
		end
		
		module User
			def member_of(deep = false)
			end
		end
	end

	module PolicyManager
		def get_policies(entity)
		end
		
		def modify_policy(entity, path, rights = nil)
		end
	end
end