#!/usr/bin/env ruby
require 'rubygems'
require 'oauth2'
require 'cgi'

class CFClient

  @@domain_name = ENV["DOMAIN_NAME"]

	def initialize(client_id, client_secret, uaa_url)
    @client = OAuth2::Client.new(
      client_id,
      client_secret,
      :site => uaa_url)

		@token = @client.client_credentials.get_token;

	end

  def api_url

    return "https://api.#{@@domain_name}/v2"

  end

  def get_organizations

    response = @token.get("#{api_url}/organizations")
    orgs = response.parsed

  end

  def get_organization_by_name(org_name)

    org = nil

    response = @token.get("#{api_url}/organizations?q=name:#{org_name}")
    if response.parsed["total_results"] == 1
      org = response.parsed['resources'][0]
    end

    return org

  end

  def get_organization_quota_by_name(org_name)

    quota = nil

    response = @token.get("#{api_url}/quota_definitions?q=name:#{org_name}")
    if response.parsed["total_results"] == 1
      quota = response.parsed['resources'][0]
    end

    return quota

  end

  def get_organization_spaces(org_guid)

    response = @token.get("#{api_url}/organizations/#{(org_guid)}/spaces")
    spaces = response.parsed["resources"]

  end

  def get_users

    response = @token.get("#{api_url}/users?order-direction=desc")
    users = response.parsed["resources"];

  end

  def add_user_to_org(user_guid, org_guid)

    # Add user to org
    @token.put("#{api_url}/organizations/#{org_guid}/users/#{user_guid}")

  end


  def create_organization(org_name, quota_definition_guid)

    req = {
      name: org_name,
      quota_definition_guid: quota_definition_guid
    }

    response = @token.post("#{api_url}/organizations", body: req.to_json)
    org = response.parsed

  end

  def create_space(name, organization_guid, developer_guids, manager_guids, space_quota_guid)

    req = {
      name: name,
      organization_guid: organization_guid,
      developer_guids: developer_guids,
      manager_guids: manager_guids,
      space_quota_definition_guid: space_quota_guid
    }
    sr = @token.post("#{api_url}/spaces",
        body: req.to_json)
    space = sr.parsed
    space_guid = space["metadata"]["guid"]

    self.add_space_asg(space_guid, "public_networks_egress")
    self.add_space_asg(space_guid, "trusted_local_networks_egress")

  end

  def add_space_asg(space_guid, asg_name)

    asg_response = @token.get("#{api_url}/security_groups?q=name:#{CGI.escape asg_name}")
    asg = asg_response.parsed
    asg_guid = asg["results"][0]["metadata"]["guid"]

    bind_asg_response = @token.put("#{api_url}/security_groups/#{CGI.escape asg_guid}/spaces/#{CGI.escape space_guid}")

  end


  def get_organization_quota(org_guid)

    response = @token.get("#{api_url}/quota_definitions/#{org_guid}")
    quota = response.parsed

  end

  def increase_org_quota(org)

    quota = get_organization_quota(org['entity']['quota_definition_guid'])
    update_url = quota["metadata"]["url"]
    quota_total_routes = quota["entity"]["total_routes"]
    quota_total_services = quota["entity"]["total_services"]
    quota_memory_limit = quota["entity"]["memory_limit"]
    org_spaces = get_organization_spaces(org['metadata']['guid'])
    space_count = org_spaces.length
    computed_total_routes_services = 10 * space_count
    computed_memory_limit = 1024 * space_count
    req = {
      name: org['entity']['name'],
      non_basic_services_allowed: true,
      total_services: quota_total_services > computed_total_routes_services ? quota_total_services : computed_total_routes_services,
      total_routes: quota_total_routes > computed_total_routes_services ? quota_total_routes : computed_total_routes_services,
      memory_limit: quota_memory_limit > computed_memory_limit ? quota_memory_limit : computed_memory_limit,
      instance_memory_limit: -1
    }
    # Update quota definition
    response = @token.put("#{api_url}/quota_definitions/" + quota["metadata"]["guid"],
      body: req.to_json)

  end

  def create_organization_quota(org_name)

    req = {
      name: org_name,
      non_basic_services_allowed: false,
      total_services: 10,
      total_routes: 10,
      memory_limit: 1024,
      instance_memory_limit: -1
    }

    response = @token.post("#{api_url}/quota_definitions", body: req.to_json)
    org_quota = response.parsed

  end


  def create_organization_space_quota_definition(org_guid, space_name)

    req = {
      organization_guid: org_guid,
      name: space_name,
      non_basic_services_allowed: false,
      total_services: 10,
      total_routes: 10,
      memory_limit: 1024,
      instance_memory_limit: -1
    }

    response = @token.post("#{api_url}/space_quota_definitions", body: req.to_json)
    org_quota = response.parsed

  end


  def get_quota_definitions

    response = @token.get("#{api_url}/quota_definitions")
    quota = response.parsed

  end

  def get_space_quota_definitions

    response = @token.get("#{api_url}/space_quota_definitions")
    quota = response.parsed

  end

  def get_organization_space_quota_definitions(org_guid)

    space_quota_definitions = nil

    response = @token.get("#{api_url}/organizations/#{org_guid}/space_quota_definitions")

    if response.parsed["total_results"] != 0
      space_quota_definitions = response.parsed['resources']
    end

    return space_quota_definitions

  end

  def get_organization_space_quota_definition_by_name(org_guid, name)

    space_quota_definition = nil

    space_quota_definitions = get_organization_space_quota_definitions(org_guid)

    if space_quota_definitions
      space_quota_definitions.each do |quota_definition|
        if quota_definition['entity']['name'] == name
          space_quota_definition = quota_definition
          break
        end
      end
    end

    space_quota_definition

  end

  def organization_space_name_exists?(org_guid, space_name)

    response = @token.get("#{api_url}/organizations/#{(org_guid)}/spaces?q=name:#{CGI.escape space_name}")
    return response.parsed["total_results"] == 1

  end

end
