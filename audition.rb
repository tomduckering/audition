require 'rubygems'
require 'sinatra'
require 'json'


configure do
  set :repo_root, 'test_root'
end

get "/repos" do
  repos_glob_pattern = File.join(settings.repo_root, '*')
  puts repos_glob_pattern
  directories_in_repo_root = Dir.glob(repos_glob_pattern).select {|f| File.directory? f}.map {|dir| File.basename dir}
  JSON.pretty_generate(directories_in_repo_root)
end

get "/repos/:repo_name" do
  repo_name = params[:repo_name]
  repo_path = File.join(settings.repo_root, repo_name)

  status 404 unless Dir.exists? (repo_path)

  repo_data_file_path = File.join(repo_path,"repo_data.json")

  status 500 unless File.exists? (repo_data_file_path)

  File.open(repo_data_file_path,'r').read

end

put "/repos/:repo_name" do
  repo_name = params[:repo_name]
  repo_path = File.join(settings.repo_root, repo_name)

  if ! Dir.exists? (repo_path)
    FileUtils.mkdir_p(repo_path)
  end

  repo_data = JSON.parse(request.body.read)
  status 400 unless repo_data.include? 'stages'

  repo_data_file_path = File.join(repo_path,"repo_data.json")
  File.open(repo_data_file_path,'w').write(JSON.pretty_generate(repo_data))

  repo_data['stages'].each do |stage|
    stage_directory = File.join(repo_path,stage)
    FileUtils.mkdir_p(stage_directory)
  end

  status 200
end

get "/repos/:repo_name/stages/:stage_name" do
  repo_name = params[:repo_name]
  stage_name = params[:stage_name]

  stage_path = File.join(settings.repo_root,repo_name,stage_name)
  glob_pattern = File.join(stage_path, '*.rpm')

  JSON.pretty_generate(Dir.glob(glob_pattern).map {|rpm| File.basename rpm})

end

post "/repos/:repo_name/stages/:stage_name/promote/:artifact_name" do
  repo_name = params[:repo_name]
  stage_name = params[:stage_name]
  artifact_name = params[:artifact_name]

  stage_path = File.join(settings.repo_root,repo_name,stage_name)
  current_artifact_path = File.join(stage_path, artifact_name)
  status 400 unless File.exists?(current_artifact_path)

  repo_path = File.join(settings.repo_root, repo_name)
  repo_data_file_path = File.join(repo_path,"repo_data.json")
  repo_data = JSON.parse(File.open(repo_data_file_path,'r').read)

  index_of_current_stage = repo_data['stages'].index(stage_name)
  index_of_next_stage = index_of_current_stage + 1

  if repo_data['stages'].size <= index_of_next_stage
    status 400
    body "No further stages to promote to. Current stage: \"#{stage_name}\", Stages: #{repo_data['stages'].to_s}"
    return
  end

  next_stage_name = repo_data['stages'][index_of_next_stage]
  next_stage_path = File.join(settings.repo_root,repo_name,next_stage_name)
  promoted_artifact_path = File.join(next_stage_path,artifact_name)

  FileUtils.copy(current_artifact_path,promoted_artifact_path)

  #Regenerate index in the next stage

end