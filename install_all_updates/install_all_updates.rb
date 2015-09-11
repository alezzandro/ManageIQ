#
#            Automate Method
#

begin
  @method = 'install_all_updates'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

	require 'rest-client'
	require 'json'

	# Dump all of root's attributes to the log
	$evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} Root:<$evm.root> Attribute - #{k}: #{v}")}

	vm=$evm.root["vm"]
	if not vm.hostnames[0].nil?
		host=vm.hostnames[0]
		$evm.log("info", "Found FQDN #{host} for this VM")
	else
      host="#{vm.name}.example.com"
		$evm.log("info", "Found no FQDN for this VM, will try #{host} instead")
	end

	@foreman_host = $evm.object['foreman_host']
	@foreman_user = $evm.object['foreman_user']
	@foreman_password = $evm.object.decrypt('foreman_password')

  def get_json(location)
  	response = RestClient::Request.new(
  		:method => :get,
  		:url => location,
  		:verify_ssl => false,
  		:user => @foreman_user,
  		:password => @foreman_password,
  		:headers => { :accept => :json,
  		:content_type => :json }
  	).execute

  	results = JSON.parse(response.to_str)
  end

  def put_json(location, json_data)
  	response = RestClient::Request.new(
  		:method => :put,
  		:url => location,
  		:verify_ssl => false,
  		:user => @foreman_user,
  		:password => @foreman_password,
  		:headers => { :accept => :json,
  		:content_type => :json},
  		:payload => json_data
  	).execute
  	results = JSON.parse(response.to_str)
  end

	url = "https://#{@foreman_host}/api/v2/"
	katello_url = "https://#{@foreman_host}/katello/api/v2/"

  systems = get_json(katello_url+"systems")
  uuid = {}
  hostExists = false
  systems['results'].each do |system|
		$evm.log("info","Current Name: #{system["name"]} comparing to #{host}")
  	if system['name'].include? host
  		$evm.log("info","Host ID #{system['id']}")
  		$evm.log("info","Host UUID #{system['uuid']}")
  		uuid = system['uuid'].to_s
  		hostExists = true
      break
  	end
  end

  if !hostExists
    $evm.log("info", "Host #{host} not found on Satellite")
    exit MIQ_OK
  end

  erratas = get_json(katello_url+"systems/"+uuid+"/errata")
  errata_list = Array.new
  erratas['results'].each do |errata|
  	errata_id = errata['errata_id']
  	$evm.log("info", "Errata id[#{errata["errata_id"]}] title[#{errata["title"]} severity[#{errata["severity"]} found")
  	errata_list.push errata_id
  end

  if erratas['results'].nil? || erratas['results'].empty?
  	$evm.log("info","No erratas found for host #{host}")
  end

  errata_result = put_json(katello_url+"systems/"+uuid+"/errata/apply", JSON.generate({"errata_ids"=>errata_list}))

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end

exit()
