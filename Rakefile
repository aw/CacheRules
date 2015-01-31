desc "Run the tests"
task :test do
  run_test
end

def run_test
  require 'rake/testtask'

  Rake::TestTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/helper.rb', 'test/test_*.rb']
  end

end
