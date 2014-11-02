define :kn_go_build do
	#application = params[:app]
	deploy = params[:deploy_data]

	go_main_dir = deploy[:go_main_dir] # "trynk"
	deploy_to = deploy[:deploy_to]
	new_release_dir = Time.now.strftime("%Y-%m-%dT%H%M-%S")
	releases_dir = "#{deploy_to}/releases"
	go_path = "#{releases_dir}/#{new_release_dir}"

	go_repository = deploy[:go_repository]
	branch_name = deploy[:scm][:revision]

	#create go root
	directory "#{go_path}" do
		group deploy[:group]
		owner deploy[:user]
		mode "0775"
		action :create
		recursive true
	end

	#go base dirs
	['src','bin','pkg'].each do |dir_name|
		directory "#{go_path}/#{dir_name}" do
			group deploy[:group]
			owner deploy[:user]
			mode "0775"
			action :create
			recursive true
		end
	end

	ensure_scm_package_installed('git')

    prepare_git_checkouts(
      :user => deploy[:user],
      :group => deploy[:group],
      :home => deploy[:home],
      :ssh_key => deploy[:scm][:ssh_key]
    ) 

	parts = go_repository.split("/")
	prev = "#{go_path}/src" 
	#we have to do this retarded thing because the owner and group only apply to 
	#leaf nodes on creating a recursive structure
	parts.each do |dir_name| 
		current = "#{prev}/#{dir_name}" 
		directory current do
			group deploy[:group]
			owner deploy[:user]
			mode "0775"
			action :create
			recursive false
		end
		prev = current
	end
	checkout_to =  "#{go_path}/src/#{go_repository}"

	#go source
	directory "#{checkout_to}" do
		group deploy[:group]
		owner deploy[:user]
		mode "0775"
		action :create
		recursive true
	end
	
	git "#{checkout_to}"  do
		repository "#{deploy[:scm][:repository]}"	
		revision branch_name
		action :sync
		user deploy[:user]
		group deploy[:group]
	end

	execute '/usr/local/go/bin/go get; /usr/local/go/bin/go install;' do 
		cwd "#{checkout_to}/#{go_main_dir}"
		environment ({
			'GOPATH' => "#{go_path}",
			'GOBIN' => "#{go_path}/bin"
		})
		user deploy[:user]
		group deploy[:group]
	end

	#be good to also run ginkgo tests
	#coverage also
	#
	
	link "#{deploy_to}/current" do
		to "#{go_path}/"
		owner deploy[:user]
		group deploy[:group]
	end

	#cleanup
	sorted_dirs = ::Dir["#{releases_dir}/*"].sort.reverse
	max_index = sorted_dirs.length - 1
	for i in 5..max_index
		current = sorted_dirs[i]
		directory "#{current}" do
			action :delete
			recursive true
		end
	end

	

end