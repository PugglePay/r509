require 'spec_helper'
require 'r509/config'
require 'r509/exceptions'

describe R509::Config::CaConfigPool do
    context "defined manually" do
        it "has no configs" do
            pool = R509::Config::CaConfigPool.new({})

            pool["first"].should == nil
        end

        it "has one config" do
            config = R509::Config::CaConfig.new(
                :ca_cert => TestFixtures.test_ca_cert,
                :profiles => { "first_profile" => R509::Config::CaProfile.new }
            )

            pool = R509::Config::CaConfigPool.new({
                "first" => config
            })

            pool["first"].should == config
        end
    end

    context "all configs" do
        it "no configs" do
            pool = R509::Config::CaConfigPool.new({})
            pool.all.should == []
        end

        it "one config" do
            config = R509::Config::CaConfig.new(
                :ca_cert => TestFixtures.test_ca_cert,
                :profiles => { "first_profile" => R509::Config::CaProfile.new }
            )

            pool = R509::Config::CaConfigPool.new({
                "first" => config
            })

            pool.all.should == [config]
        end

        it "two configs" do
            config1 = R509::Config::CaConfig.new(
                :ca_cert => TestFixtures.test_ca_cert,
                :profiles => { "first_profile" => R509::Config::CaProfile.new }
            )
            config2 = R509::Config::CaConfig.new(
                :ca_cert => TestFixtures.test_ca_cert,
                :profiles => { "first_profile" => R509::Config::CaProfile.new }
            )

            pool = R509::Config::CaConfigPool.new({
                "first" => config1,
                "second" => config2
            })

            pool.all.size.should == 2
            pool.all.include?(config1).should == true
            pool.all.include?(config2).should == true
        end
    end

    context "loaded from YAML" do
        it "should load two configs" do
            pool = R509::Config::CaConfigPool.from_yaml("certificate_authorities", File.read("#{File.dirname(__FILE__)}/fixtures/config_pool_test_minimal.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})

            pool.names.should include("test_ca", "second_ca")

            pool["test_ca"].should_not == nil
            pool["test_ca"].num_profiles.should == 0
            pool["second_ca"].should_not == nil
            pool["second_ca"].num_profiles.should == 0
        end
    end
end

describe R509::Config::CaConfig do
    before :each do
        @config = R509::Config::CaConfig.new(
            :ca_cert => TestFixtures.test_ca_cert
        )
    end

    subject {@config}

    its(:message_digest) {should == "SHA1"}
    its(:crl_validity_hours) {should == 168}
    its(:ocsp_validity_hours) {should == 168}
    its(:ocsp_start_skew_seconds) {should == 3600}
    its(:cdp_location) {should be_nil}
    its(:ocsp_location) {should be_nil}
    its(:num_profiles) {should == 0}

    it "should have the proper CA cert" do
        @config.ca_cert.to_pem.should == TestFixtures.test_ca_cert.to_pem
    end

    it "should have the proper CA key" do
        @config.ca_cert.key.to_pem.should == TestFixtures.test_ca_cert.key.to_pem
    end

    it "raises an error if you don't pass :ca_cert" do
        expect { R509::Config::CaConfig.new(:crl_validity_hours => 2) }.to raise_error ArgumentError, 'Config object requires that you pass :ca_cert'
    end
    it "raises an error if :ca_cert is not of type R509::Cert" do
        expect { R509::Config::CaConfig.new(:ca_cert => 'not a cert, and not right type') }.to raise_error ArgumentError, ':ca_cert must be of type R509::Cert'
    end
    it "loads the config even if :ca_cert does not contain a private key" do
        config = R509::Config::CaConfig.new( :ca_cert => R509::Cert.new( :cert => TestFixtures::TEST_CA_CERT) )
        config.ca_cert.subject.to_s.should_not be_nil
    end
    it "raises an error if :ocsp_cert that is not R509::Cert" do
        expect { R509::Config::CaConfig.new(:ca_cert => TestFixtures.test_ca_cert, :ocsp_cert => "not a cert") }.to raise_error ArgumentError, ':ocsp_cert, if provided, must be of type R509::Cert'
    end
    it "raises an error if :ocsp_cert does not contain a private key" do
        expect { R509::Config::CaConfig.new( :ca_cert => TestFixtures.test_ca_cert, :ocsp_cert => R509::Cert.new( :cert => TestFixtures::TEST_CA_CERT) ) }.to raise_error ArgumentError, ':ocsp_cert must contain a private key, not just a certificate'
    end
    it "returns the correct cert object on #ocsp_cert if none is specified" do
        @config.ocsp_cert.should == @config.ca_cert
    end
    it "returns the correct cert object on #ocsp_cert if an ocsp_cert was specified" do
        ocsp_cert = R509::Cert.new(
            :cert => TestFixtures::TEST_CA_OCSP_CERT,
            :key => TestFixtures::TEST_CA_OCSP_KEY
        )
        config = R509::Config::CaConfig.new(
            :ca_cert => TestFixtures.test_ca_cert,
            :ocsp_cert => ocsp_cert
        )

        config.ocsp_cert.should == ocsp_cert
    end
    it "fails to specify a non-Config::CaProfile as the profile" do
        config = R509::Config::CaConfig.new(
            :ca_cert => TestFixtures.test_ca_cert
        )

        expect{ config.set_profile("bogus", "not a Config::CaProfile")}.to raise_error TypeError
    end

    it "shouldn't let you specify a profile that's not a Config::CaProfile, on instantiation" do
        expect{ R509::Config::CaConfig.new(
            :ca_cert => TestFixtures.test_ca_cert,
            :profiles => { "first_profile" => "not a Config::CaProfile" }
        ) }.to raise_error TypeError
    end

    it "can specify a single profile" do
        first_profile = R509::Config::CaProfile.new

        config = R509::Config::CaConfig.new(
            :ca_cert => TestFixtures.test_ca_cert,
            :profiles => { "first_profile" => first_profile }
        )

        config.profile("first_profile").should == first_profile
    end

    it "raises an error if you specify an invalid profile" do
        first_profile = R509::Config::CaProfile.new

        config = R509::Config::CaConfig.new(
            :ca_cert => TestFixtures.test_ca_cert,
            :profiles => { "first_profile" => first_profile }
        )

        expect { config.profile("non-existent-profile") }.to raise_error(R509::R509Error, "unknown profile 'non-existent-profile'")
    end

    it "should load YAML" do
        config = R509::Config::CaConfig.from_yaml("test_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})
        config.crl_validity_hours.should == 72
        config.ocsp_validity_hours.should == 96
        config.message_digest.should == "SHA1"
        config.num_profiles.should == 3
    end
    it "loads OCSP cert/key from yaml" do
        config = R509::Config::CaConfig.from_yaml("ocsp_delegate_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})
        config.ocsp_cert.has_private_key?.should == true
        config.ocsp_cert.subject.to_s.should == "/C=US/ST=Illinois/L=Chicago/O=r509 LLC/CN=r509 OCSP Signer"
    end
    it "loads OCSP pkcs12 from yaml" do
        config = R509::Config::CaConfig.from_yaml("ocsp_pkcs12_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})
        config.ocsp_cert.has_private_key?.should == true
        config.ocsp_cert.subject.to_s.should == "/C=US/ST=Illinois/L=Chicago/O=r509 LLC/CN=r509 OCSP Signer"
    end
    it "loads OCSP cert/key in engine from yaml" do
        #most of this code path is tested by loading ca_cert engine.
        #look there for the extensive doubling
        expect { R509::Config::CaConfig.from_yaml("ocsp_engine_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to raise_error(R509::R509Error,"You must supply a key_name with an engine")
    end
    it "loads OCSP chain from yaml" do
        config = R509::Config::CaConfig.from_yaml("ocsp_chain_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})
        config.ocsp_chain.size.should == 2
        config.ocsp_chain[0].kind_of?(OpenSSL::X509::Certificate).should == true
        config.ocsp_chain[1].kind_of?(OpenSSL::X509::Certificate).should == true
    end
    it "should load subject_item_policy from yaml (if present)" do
        config = R509::Config::CaConfig.from_yaml("test_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})
        config.profile("server").subject_item_policy.should be_nil
        config.profile("server_with_subject_item_policy").subject_item_policy.optional.should include("O","OU")
        config.profile("server_with_subject_item_policy").subject_item_policy.required.should include("CN","ST","C")
    end

    it "should load YAML which only has a CA Cert and Key defined" do
        config = R509::Config::CaConfig.from_yaml("test_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_minimal.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})
        config.num_profiles.should == 0
    end

    it "should load YAML which has CA cert and key with password" do
        expect { R509::Config::CaConfig.from_yaml("password_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_password.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to_not raise_error
    end

    it "should load YAML which has a PKCS12 with password" do
        expect { R509::Config::CaConfig.from_yaml("pkcs12_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to_not raise_error
    end

    it "raises error on YAML with pkcs12 and key" do
        expect { R509::Config::CaConfig.from_yaml("pkcs12_key_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to raise_error(R509::R509Error, "You can't specify both pkcs12 and key")
    end

    it "raises error on YAML with pkcs12 and cert" do
        expect { R509::Config::CaConfig.from_yaml("pkcs12_cert_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to raise_error(R509::R509Error, "You can't specify both pkcs12 and cert")
    end

    it "raises error on YAML with pkcs12 and engine" do
        expect { R509::Config::CaConfig.from_yaml("pkcs12_engine_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to raise_error(R509::R509Error, "You can't specify both engine and pkcs12")
    end

    it "loads config with cert and no key (useful in certain cases)" do
        config = R509::Config::CaConfig.from_yaml("cert_no_key_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_various.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})
        config.ca_cert.subject.to_s.should_not be_nil
    end

    it "should load YAML which has an engine" do
        #i can test this, it's just gonna take a whole lot of floorin' it!
        conf = double("conf")
        engine = double("engine")
        faux_key = double("faux_key")

        public_key = OpenSSL::PKey::RSA.new("-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqLfP8948QEZMMkZNHLDP\nOHZVrPdVvecD6bp8dz96LalMQiWjgMkJf7mPHXoNMQ5rIpntiUOmhupu+sty30+C\ndbZZIbZohioTSYq9ZIC/LC9ME12F78GRMKhBGA+ZiouzWvXqOEdMnanfSgKrlSIS\nssF71dfmOEQ08fn9Vl5jAgWmGe+v615iHqBNGr64kYooTrZYLaPlTScO1UZ76vnB\nHfNQU+tsEZNXxtZXKQqkxHxLShCOj6qmYRNn/upTZoWWd04+zXjYGEC3eKvi9ctN\n9FY+KJ6QCCa8H0Kt3cU5qyw6pzdljhbG6NKhod7OMqlGjmHdsCAYAqe3xH+V/8oe\ndwIDAQAB\n-----END PUBLIC KEY-----\n")

        conf.should_receive(:kind_of?).with(Hash).and_return(true)
        conf.should_receive(:[]).with("ca_cert").and_return(
            "cert" => "#{File.dirname(__FILE__)}/fixtures/test_ca.cer",
            "engine" => engine,
            "key_name" => "r509_key"
        )
        conf.should_receive(:[]).at_least(1).times.and_return(nil)
        conf.should_receive(:has_key?).at_least(1).times.and_return(false)

        engine.should_receive(:respond_to?).with(:load_private_key).and_return(true)
        engine.should_receive(:kind_of?).with(OpenSSL::Engine).and_return(true)
        faux_key.should_receive(:public_key).and_return(public_key)
        engine.should_receive(:load_private_key).with("r509_key").and_return(faux_key)

        config = R509::Config::CaConfig.load_from_hash(conf)
    end

    it "should fail if YAML for ca_cert contains engine and key" do
        expect { R509::Config::CaConfig.from_yaml("engine_and_key", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_engine_key.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to raise_error(R509::R509Error, "You can't specify both key and engine")
    end

    it "should fail if YAML for ca_cert contains engine but no key_name" do
        expect { R509::Config::CaConfig.from_yaml("engine_no_key_name", File.read("#{File.dirname(__FILE__)}/fixtures/config_test_engine_no_key_name.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to raise_error(R509::R509Error, 'You must supply a key_name with an engine')
    end

    it "should fail if YAML config is null" do
        expect{ R509::Config::CaConfig.from_yaml("no_config_here", File.read("#{File.dirname(__FILE__)}/fixtures/config_test.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to raise_error(ArgumentError)
    end

    it "should fail if YAML config isn't a hash" do
        expect{ R509::Config::CaConfig.from_yaml("config_is_string", File.read("#{File.dirname(__FILE__)}/fixtures/config_test.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"}) }.to raise_error(ArgumentError)
    end

    it "should fail if YAML config doesn't give a root CA directory that's a directory" do
        expect{ R509::Config::CaConfig.from_yaml("test_ca", File.read("#{File.dirname(__FILE__)}/fixtures/config_test.yaml"), {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures/no_directory_here"}) }.to raise_error(R509::R509Error)
    end

    it "should load YAML from filename" do
        config = R509::Config::CaConfig.load_yaml("test_ca", "#{File.dirname(__FILE__)}/fixtures/config_test.yaml", {:ca_root_path => "#{File.dirname(__FILE__)}/fixtures"})
        config.crl_validity_hours.should == 72
        config.ocsp_validity_hours.should == 96
        config.message_digest.should == "SHA1"
    end

    it "can specify crl_number_file" do
        config = R509::Config::CaConfig.new(
            :ca_cert => TestFixtures.test_ca_cert,
            :crl_number_file => "crl_number_file.txt"
        )
        config.crl_number_file.should == 'crl_number_file.txt'
    end

    it "can specify crl_list_file" do
        config = R509::Config::CaConfig.new(
            :ca_cert => TestFixtures.test_ca_cert,
            :crl_list_file => "crl_list_file.txt"
        )
        config.crl_list_file.should == 'crl_list_file.txt'
    end

end

describe R509::Config::SubjectItemPolicy do
    it "raises an error if you supply a non-hash" do
        expect { R509::Config::SubjectItemPolicy.new('string') }.to raise_error(ArgumentError, "Must supply a hash in form 'shortname'=>'required/optional'")
    end
    it "raises an error if a required element is missing" do
        subject_item_policy = R509::Config::SubjectItemPolicy.new("CN" => "required", "O" => "required", "OU" => "optional", "L" => "required")
        subject = R509::Subject.new [["CN","langui.sh"],["OU","Org Unit"],["O","Org"]]
        expect { subject_item_policy.validate_subject(subject) }.to raise_error(R509::R509Error, /This profile requires you supply/)
    end
    it "raises an error if your hash values are anything other than required or optional" do
        expect { R509::Config::SubjectItemPolicy.new("CN" => "somethirdoption") }.to raise_error(ArgumentError, "Unknown subject item policy value. Allowed values are required and optional")
    end
    it "validates a subject with the same fields as the policy" do
        subject_item_policy = R509::Config::SubjectItemPolicy.new("CN" => "required", "O" => "required", "OU" => "optional")
        subject = R509::Subject.new [["CN","langui.sh"],["OU","Org Unit"],["O","Org"]]
        validated_subject = subject_item_policy.validate_subject(subject)
        validated_subject.to_s.should == subject.to_s
    end
    it "does not match if you get case of subject_item_policy element wrong" do
        subject_item_policy = R509::Config::SubjectItemPolicy.new("cn" => "required")
        subject = R509::Subject.new [["CN","langui.sh"]]
        expect { subject_item_policy.validate_subject(subject) }.to raise_error(R509::R509Error, 'This profile requires you supply cn')
    end
    it "removes subject items that are not in the policy" do
        subject_item_policy = R509::Config::SubjectItemPolicy.new("CN" => "required")
        subject = R509::Subject.new [["CN","langui.sh"],["OU","Org Unit"],["O","Org"]]
        validated_subject = subject_item_policy.validate_subject(subject)
        validated_subject.to_s.should == "/CN=langui.sh"
    end
    it "does not reorder subject items as it validates" do
        subject_item_policy = R509::Config::SubjectItemPolicy.new("CN" => "required", "O" => "required", "OU" => "optional", "L" => "required")
        subject = R509::Subject.new [["L","Chicago"],["CN","langui.sh"],["OU","Org Unit"],["O","Org"]]
        validated_subject = subject_item_policy.validate_subject(subject)
        validated_subject.to_s.should == subject.to_s
    end
    it "loads all the required and optional elements" do
        subject_item_policy = R509::Config::SubjectItemPolicy.new("CN" => "required", "O" => "required", "OU" => "optional", "L" => "required", "emailAddress" => "optional")
        subject_item_policy.optional.should include("OU","emailAddress")
        subject_item_policy.required.should include("CN","O","L")
    end
end
