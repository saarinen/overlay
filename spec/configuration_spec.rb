require "spec_helper"

describe Overlay::Configuration do

  subject { Overlay::Configuration.new }

  it "responds to #site" do
    expect(subject).to respond_to(:site)
  end
  describe "#site" do
    it "stores site" do
      subject.site = "foo"
      expect(subject.site).to eq("foo")
    end
  end

  it "responds to #endpoint" do
    expect(subject).to respond_to(:endpoint)
  end
  describe "#endpoint" do
    it "stores endpoint" do
      subject.endpoint = "foo"
      expect(subject.endpoint).to eq("foo")
    end
  end

  it "responds to #repo" do
    expect(subject).to respond_to(:repo)
  end
  describe "#repo" do
    it "stores repo" do
      subject.repo = "foo"
      expect(subject.repo).to eq("foo")
    end
  end

  it "responds to #user" do
    expect(subject).to respond_to(:user)
  end
  describe "#user" do
    it "stores user" do
      subject.user = "foo"
      expect(subject.user).to eq("foo")
    end
  end

  it "responds to #auth" do
    expect(subject).to respond_to(:auth)
  end
  describe "#auth" do
    it "stores auth" do
      subject.auth = "foo"
      expect(subject.auth).to eq("foo")
    end
  end

  it "responds to #repositories" do
    expect(subject).to respond_to(:repositories)
  end
  describe "#repositories" do
    it "stores repositories" do
      subject.repositories = "foo"
      expect(subject.repositories).to eq("foo")
    end
  end

  it "responds to #host_name" do
    expect(subject).to respond_to(:host_name)
  end
  describe "#host_name" do
    it "stores host_name" do
      subject.host_name = "foo"
      expect(subject.host_name).to eq("foo")
    end
  end

  it "responds to #host_port" do
    expect(subject).to respond_to(:host_port)
  end
  describe "#host_port" do
    it "stores host_port" do
      subject.host_port = "foo"
      expect(subject.host_port).to eq("foo")
    end
  end

  it "responds to #relative_root_url" do
    expect(subject).to respond_to(:relative_root_url)
  end
  describe "#relative_root_url" do
    it "stores relative_root_url" do
      subject.relative_root_url = "foo"
      expect(subject.relative_root_url).to eq("foo")
    end
  end

  describe "#reset" do
    it "sets #site back to https://github.com" do
      subject.site = "foo"
      subject.reset
      expect(subject.site).to eq("https://github.com")
    end
    it "sets #endpoint back to https://api.github.com" do
      subject.endpoint = "foo"
      subject.reset
      expect(subject.endpoint).to eq("https://api.github.com")
    end
    it "sets #repositories back to an empty set" do
      subject.repositories = "foo"
      subject.reset
      expect(subject.repositories).to be_a(Set)
      expect(subject.repositories).to be_empty
    end
  end

  describe "#after_overlay" do
    it "requires a block" do
      expect { subject.after_overlay }.to raise_error(ArgumentError)
    end
    it "can only be set once" do
      expect {
        subject.after_overlay {}
        subject.after_overlay {}
      }.to raise_error(Overlay::PostHookExists)
    end
  end

  describe "#post_hook" do
    it "executes a proc previously set by #after_overlay" do
      mutable = 1
      subject.after_overlay { mutable += 1 }
      subject.post_hook
      subject.post_hook
      expect(mutable).to eq(3)
    end
  end

end
