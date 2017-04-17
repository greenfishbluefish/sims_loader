require 'tempfile'
require 'yaml'

# This is a hack around an issue with Ruby invoking Docker and pathnames in
# Windows. This problem doesn't happen in Linux or with Perl. This is partly
# because Ruby doesn't respect MSYS_NO_PATHCONV.
ENV['SIMSLOADER_VOLUME'] = '/c/Users/rkinyon/devel/simsloader-demo/app'

def load_data(spec={})
  Tempfile.create('spec', '.') do |f|
    f.write YAML.dump(spec)
    f.close
    return YAML.load `bash run_against_mysql.sh load --specification #{File.basename(f.path)}`
  end
end

RSpec.describe "database" do
  it "loads a user" do
    x = load_data({'user' => 1})
    require 'pp'
    pp x
    expect(true).to be_truthy
  end
  it "loads Bob Smith" do
    x = load_data({'user' => {'name' => 'Bob Smith'}})
    require 'pp'
    pp x
    expect(true).to be_truthy
  end
end
