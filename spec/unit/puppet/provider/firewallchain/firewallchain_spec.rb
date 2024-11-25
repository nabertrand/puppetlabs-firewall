# frozen_string_literal: true

require 'spec_helper'
require 'puppet/resource_api'

ensure_module_defined('Puppet::Provider::Firewallchain')
require 'puppet/provider/firewallchain/firewallchain'

RSpec.describe Puppet::Provider::Firewallchain::Firewallchain do
  describe 'Public Methods' do
    subject(:provider) { described_class.new }

    let(:type) { Puppet::Type.type('firewallchain') }
    let(:context) { Puppet::ResourceApi::BaseContext.new(type.type_definition.definition) }

    describe 'get(_context)' do
      let(:iptables) do
        '
# Generated by iptables-save v1.8.4 on Thu Aug 10 10:15:14 2023
*filter
:INPUT ACCEPT [62:3308]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [39:3092]
:TEST_ONE - [0:0]
COMMIT
# Completed on Thu Aug 10 10:15:14 2023
# Generated by iptables-save v1.8.4 on Thu Aug 10 10:15:14 2023
*raw
:PREROUTING ACCEPT [13222:23455532]
:OUTPUT ACCEPT [12523:852730]
:TEST_TWO - [0:0]
COMMIT
# Completed on Thu Aug 10 10:15:14 2023
        '
      end
      let(:ip6tables) do
        '
# Generated by ip6tables-save v1.8.4 on Thu Aug 10 10:21:55 2023
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [13:824]
COMMIT
# Completed on Thu Aug 10 10:21:55 2023
        '
      end
      let(:returned_data) do
        [{ name: 'INPUT:filter:IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
         { name: 'FORWARD:filter:IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
         { name: 'OUTPUT:filter:IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
         { name: 'TEST_ONE:filter:IPv4', purge: false, ignore_foreign: false, ensure: 'present' },
         { name: 'PREROUTING:raw:IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
         { name: 'OUTPUT:raw:IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
         { name: 'TEST_TWO:raw:IPv4', purge: false, ignore_foreign: false, ensure: 'present' },
         { name: 'INPUT:filter:IPv6', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
         { name: 'FORWARD:filter:IPv6', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
         { name: 'OUTPUT:filter:IPv6', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' }]
      end

      it 'processes the resource' do
        allow(Puppet::Util::Execution).to receive(:execute).with('iptables-save').and_return(iptables)
        allow(Puppet::Util::Execution).to receive(:execute).with('ip6tables-save').and_return(ip6tables)

        expect(provider.get(context)).to eq(returned_data)
      end
    end

    describe 'create(context, name, should)' do
      [
        {
          should: { name: 'TEST_ONE:filter:IPv4', chain: 'TEST_ONE', table: 'filter', protocol: 'IPv4', purge: false, ignore_foreign: false, ensure: 'present' },
          create_command: 'iptables -t filter -N TEST_ONE'
        },
        {
          should: { name: 'TEST_TWO:raw:IPv6', chain: 'TEST_TWO', table: 'raw', protocol: 'IPv6', purge: false, ignore_foreign: false, ensure: 'present' },
          create_command: 'ip6tables -t raw -N TEST_TWO'
        },
      ].each do |test|
        it "creates the resource: '#{test[:should][:name]}'" do
          expect(context).to receive(:notice).with(%r{\ACreating Chain '#{test[:should][:name]}'})
          expect(Puppet::Util::Execution).to receive(:execute).with(test[:create_command])
          allow(PuppetX::Firewall::Utility).to receive(:persist_iptables).with(context, test[:should][:name], test[:should][:protocol])

          provider.create(context, test[:should][:name], test[:should])
        end
      end
    end

    describe 'update(context, name, should, is)' do
      context 'when passed valid input' do
        [
          {
            should: { name: 'INPUT:filter:IPv4', chain: 'INPUT', table: 'filter', protocol: 'IPv4', ensure: 'present', policy: 'drop' },
            is: { name: 'INPUT:filter:IPv4', chain: 'INPUT', table: 'filter', protocol: 'IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
            update_command: 'iptables -t filter -P INPUT DROP'
          },
          {
            should: { name: 'OUTPUT:raw:IPv6', chain: 'OUTPUT', table: 'raw', protocol: 'IPv6', ensure: 'present', policy: 'queue' },
            is: { name: 'OUTPUT:raw:IPv6', chain: 'OUTPUT', table: 'raw', protocol: 'IPv6', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
            update_command: 'ip6tables -t raw -P OUTPUT QUEUE'
          },
        ].each do |test|
          it "updates the resource: '#{test[:should]}'" do
            expect(context).to receive(:notice).with(%r{\AUpdating Chain '#{test[:should][:name]}'})
            expect(Puppet::Util::Execution).to receive(:execute).with(test[:update_command])
            allow(PuppetX::Firewall::Utility).to receive(:persist_iptables).with(context, test[:should][:name], test[:should][:protocol])

            provider.update(context, test[:should][:name], test[:should], test[:is])
          end
        end
      end

      context 'when passed invalid input' do
        [
          {
            should: { name: 'INPUT:filter:IPv4', chain: 'INPUT', table: 'filter', protocol: 'IPv4', ensure: 'present', policy: 'accept' },
            is: { name: 'INPUT:filter:IPv4', chain: 'INPUT', table: 'filter', protocol: 'IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
            update_command: 'iptables -t filter -P INPUT DROP'
          },
          {
            should: { name: 'TEST_ONE:raw:IPv6', chain: 'TEST_ONE', table: 'raw', protocol: 'IPv6', ensure: 'present', policy: 'queue' },
            is: { name: 'TEST_ONE:raw:IPv6', chain: 'TEST_ONE', table: 'raw', protocol: 'IPv6', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
            update_command: 'ip6tables -t raw -P OUTPUT QUEUE'
          },
        ].each do |test|
          it "does not update the resource: '#{test[:should]}'" do
            expect(context).not_to receive(:notice).with(%r{\AUpdating Chain '#{test[:should][:name]}'})
            expect(Puppet::Util::Execution).not_to receive(:execute).with(test[:update_command])

            provider.update(context, test[:should][:name], test[:should], test[:is])
          end
        end
      end
    end

    describe 'delete(context, name, is)' do
      context 'with custom chains' do
        [
          {
            is: { name: 'TEST_ONE:filter:IPv4', chain: 'TEST_ONE', table: 'filter', protocol: 'IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
            flush_command: 'iptables -t filter -F TEST_ONE',
            delete_command: 'iptables -t filter -X TEST_ONE'
          },
          {
            is: { name: 'TEST_TWO:raw:IPv6', chain: 'TEST_TWO', table: 'raw', protocol: 'IPv6', purge: false, ignore_foreign: false, ensure: 'present', policy: 'accept' },
            flush_command: 'ip6tables -t raw -F TEST_TWO',
            delete_command: 'ip6tables -t raw -X TEST_TWO'
          },
        ].each do |test|
          it "deletes the resource: '#{test[:is]}'" do
            allow(context).to receive(:notice).with(%r{\AFlushing Chain '#{test[:is][:name]}'})
            expect(Puppet::Util::Execution).to receive(:execute).with(test[:flush_command])
            allow(context).to receive(:notice).with(%r{\ADeleting Chain '#{test[:is][:name]}'})
            expect(Puppet::Util::Execution).to receive(:execute).with(test[:delete_command])
            allow(PuppetX::Firewall::Utility).to receive(:persist_iptables).with(context, test[:is][:name], test[:is][:protocol])

            provider.delete(context, test[:is][:name], test[:is])
          end
        end
      end

      context 'with inbuilt chains' do
        [
          {
            is: { name: 'INPUT:filter:IPv4', chain: 'INPUT', table: 'filter', protocol: 'IPv4', purge: false, ignore_foreign: false, ensure: 'present', policy: 'drop' },
            flush_command: 'iptables -t filter -F INPUT',
            revert_command: 'iptables -t filter -P INPUT ACCEPT'
          },
          {
            is: { name: 'OUTPUT:raw:IPv6', chain: 'OUTPUT', table: 'raw', protocol: 'IPv6', purge: false, ignore_foreign: false, ensure: 'present', policy: 'queue' },
            flush_command: 'ip6tables -t raw -F OUTPUT',
            revert_command: 'ip6tables -t raw -P OUTPUT ACCEPT'
          },
        ].each do |test|
          it "reverts the resource: '#{test[:is]}'" do
            allow(context).to receive(:notice).with(%r{\AFlushing Chain '#{test[:is][:name]}'})
            expect(Puppet::Util::Execution).to receive(:execute).with(test[:flush_command])
            allow(context).to receive(:notice).with(%r{\AReverting Internal Chain '#{test[:is][:name]}'})
            expect(Puppet::Util::Execution).to receive(:execute).with(test[:revert_command])
            allow(PuppetX::Firewall::Utility).to receive(:persist_iptables).with(context, test[:is][:name], test[:is][:protocol])

            provider.delete(context, test[:is][:name], test[:is])
          end
        end
      end
    end

    describe 'insync?(context, _name, property_name, _is_hash, _should_hash)' do
      [
        { name: 'TEST_ONE:filter:IPv4', property_name: :name, is_hash: {}, should_hash: {}, result: nil },
        { name: 'TEST_ONE:filter:IPv4', property_name: :policy, is_hash: {}, should_hash: {}, result: nil },
        { name: 'TEST_ONE:filter:IPv4', property_name: :purge, is_hash: {}, should_hash: {}, result: true },
        { name: 'TEST_ONE:filter:IPv4', property_name: :ignore, is_hash: {}, should_hash: {}, result: true },
        { name: 'TEST_ONE:filter:IPv4', property_name: :ignore_foreign, is_hash: {}, should_hash: {}, result: true },
        { name: 'TEST_ONE:filter:IPv4', property_name: :ensure, is_hash: {}, should_hash: {}, result: nil },
      ].each do |test|
        it "check value is insync: '#{test[:property_name]}'" do
          expect(context).to receive(:debug).with(%r{\AChecking whether '#{test[:property_name]}'})
          expect(provider.insync?(context, test[:name], test[:property_name], test[:is_hash], test[:should_hash])).to eql(test[:result])
        end
      end
    end

    describe 'generate' do
      let(:iptables) do
        '
# Generated by iptables-save v1.8.4 on Thu Aug 10 10:15:14 2023
*filter
:INPUT ACCEPT [62:3308]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [39:3092]
:TEST_ONE - [0:0]
COMMIT
-A TEST_ONE -p tcp -m comment --comment "001 test rule"
-A INPUT -p tcp -m comment --comment "004 test rule"
-A TEST_ONE -p tcp -m comment --comment "ignore_this foreign"
-A TEST_ONE -p tcp -m comment --comment "foreign"
# Completed on Thu Aug 10 10:15:14 2023
# Generated by iptables-save v1.8.4 on Thu Aug 10 10:15:14 2023
*raw
:PREROUTING ACCEPT [13222:23455532]
:OUTPUT ACCEPT [12523:852730]
COMMIT
-A OUTPUT -p tcp -m comment --comment "003 test rule"
# Completed on Thu Aug 10 10:15:14 2023
        '
      end
      let(:ip6tables) do
        '
# Generated by ip6tables-save v1.8.4 on Thu Aug 10 10:21:55 2023
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [13:824]
:TEST_TWO - [0:0]
COMMIT
-A OUTPUT -p tcp -m comment --comment "005 test rule"
# Completed on Thu Aug 10 10:21:55 2023
*raw
:PREROUTING ACCEPT [13222:23455532]
:OUTPUT ACCEPT [12523:852730]
COMMIT
-A TEST_TWO -p tcp -m comment --comment "002 test rule"
# Completed on Thu Aug 10 10:21:55 2023
        '
      end

      [
        {
          should: { name: 'TEST_ONE:filter:IPv4', purge: true, ensure: 'present' },
          purge: ['001 test rule', '9003 ignore_this foreign', '9004 foreign']
        },
        {
          should: { name: 'TEST_ONE:filter:IPv4', purge: true, ignore: 'ignore_this', ensure: 'present' },
          purge: ['001 test rule', '9004 foreign']
        },
        {
          should: { name: 'TEST_ONE:filter:IPv4', purge: true, ignore_foreign: true, ensure: 'present' },
          purge: ['001 test rule']
        },
        {
          should: { name: 'TEST_TWO:raw:IPv6', purge: true, ensure: 'present' },
          purge: ['002 test rule']
        },
      ].each do |test|
        before(:each) do
          allow(Puppet::Util::Execution).to receive(:execute).with('iptables-save').and_return(iptables)
          allow(Puppet::Util::Execution).to receive(:execute).with('ip6tables-save').and_return(ip6tables)
        end

        it "purge chain: '#{test[:should]}'" do
          resources = provider.generate(context, test[:should][:name], {}, test[:should])

          names = []
          resources.each do |resource|
            names << resource.rsapi_current_state[:name]
          end

          expect(names).to eq(test[:purge])
        end
      end
    end
  end

  describe 'Private Methods' do
    subject(:provider) { described_class }

    describe 'self.process_input(is, should)' do
      [
        {
          input: {
            is: { title: 'INPUT:filter:IPv4', purge: false, ignore_foreign: false },
            should: { name: 'INPUT:filter:IPv4', ensure: 'present' }
          },
          output: {
            is: { title: 'INPUT:filter:IPv4', name: 'INPUT:filter:IPv4', chain: 'INPUT', table: 'filter', protocol: 'IPv4', purge: false, ignore_foreign: false, policy: 'accept' },
            should: { name: 'INPUT:filter:IPv4', chain: 'INPUT', table: 'filter', protocol: 'IPv4', ensure: 'present', policy: 'accept' }
          }
        },
      ].each do |test|
        it { expect(provider.process_input(test[:input][:is], test[:input][:should])).to eql([test[:output][:is], test[:output][:should]]) }
      end
    end

    describe 'self.verify(_is, should)' do
      [
        {
          should: { name: 'PREROUTING:filter:IPv4', chain: 'PREROUTING', table: 'filter', protocol: 'IPv4', ensure: 'present', policy: 'accept' },
          error: 'INPUT, OUTPUT and FORWARD are the only inbuilt chains that can be used in table \'filter\''
        },
        {
          should: { name: 'BROUTING:mangle:IPv4', chain: 'BROUTING', table: 'mangle', protocol: 'IPv4', ensure: 'present', policy: 'accept' },
          error: 'PREROUTING, POSTROUTING, INPUT, FORWARD and OUTPUT are the only inbuilt chains that can be used in table \'mangle\''
        },
        {
          should: { name: 'FORWARD:nat:IPv4', chain: 'FORWARD', table: 'nat', protocol: 'IPv4', ensure: 'present', policy: 'accept' },
          error: 'PREROUTING, POSTROUTING, INPUT, and OUTPUT are the only inbuilt chains that can be used in table \'nat\''
        },
        {
          should: { name: 'INPUT:raw:IPv4', chain: 'INPUT', table: 'raw', protocol: 'IPv4', ensure: 'present', policy: 'accept' },
          error: 'PREROUTING and OUTPUT are the only inbuilt chains in the table \'raw\''
        },
        {
          should: { name: 'BROUTING:broute:IPv4', chain: 'BROUTING', table: 'broute', protocol: 'IPv4', ensure: 'present' },
          error: 'BROUTE is only valid with protocol \'ethernet\''
        },
        {
          should: { name: 'INPUT:broute:ethernet', chain: 'INPUT', table: 'broute', protocol: 'ethernet', ensure: 'present' },
          error: 'BROUTING is the only inbuilt chain allowed on on table \'broute\''
        },
        {
          should: { name: 'PREROUTING:security:IPv4', chain: 'PREROUTING', table: 'security', protocol: 'IPv4', ensure: 'present', policy: 'accept' },
          error: 'INPUT, OUTPUT and FORWARD are the only inbuilt chains that can be used in table \'security\''
        },
        {
          should: { name: 'TEST_ONE:filter:IPv4', chain: 'TEST_ONE', table: 'filter', protocol: 'IPv4', ensure: 'present', policy: 'accept' },
          error: '\'policy\' can only be set on Internal Chains. Setting for \'TEST_ONE:filter:IPv4\' is invalid'
        },
      ].each do |test|
        it "Expect error: #{test[:error]}" do
          expect { provider.verify({}, test[:should]) }.to raise_error(ArgumentError, test[:error])
        end
      end
    end
  end
end