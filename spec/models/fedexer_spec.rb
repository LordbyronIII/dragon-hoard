require 'spec_helper'

describe Fedexer do
  use_vcr_cassette

  context 'with a fedexer' do
    before do
      @user = FactoryGirl.create :web_user_with_address
    end

    it 'validates recipient' do
      address = @user.addresses.first

      Fedexer.recipient(@user.name, @user.addresses.first, @user.phones.first.number).should == {
       name: @user.name,
       phone_number: @user.phones.first.number,
       address: address.address_1,
       city: address.city, 
       state: address.province,
       postal_code: address.postal_code,
       country_code: address.country,
       residential: 'false'
      } 
    end 

    it 'validates sample package' do
      Fedexer.sample_package.should == 
      [{
        weight: {units: 'LB', value: 2},
        dimensions: {length: 10, width: 5, height: 4, units: 'IN'}
      }]
    end


    context 'with a package' do
      before do
        @packages = [
          {
            weight: {units: 'LB', value: 2},
            dimensions: {length: 10, width: 5, height: 4, units: 'IN'}
          }]
      end

      it 'gets a rate Fedex Ground Rate' do
        rate = Fedexer.get_rate(Fedexer.shipment, Fedexer.recipient(@user.name, @user.addresses.first, @user.phones.first.number), @packages, 'FEDEX_GROUND', Fedexer.default_shipping_details) 
        rate.should be_an_instance_of(Fedex::Rate)
      end

      it 'gets an OverNight Rate' do
        rate = Fedexer.get_rate(Fedexer.shipment, Fedexer.recipient(@user.name, @user.addresses.first, @user.phones.first.number), @packages, 'STANDARD_OVERNIGHT', Fedexer.default_shipping_details) 
        rate.should be_an_instance_of(Fedex::Rate)
      end

      it 'gets an 2 Day Rate' do
        rate = Fedexer.get_rate(Fedexer.shipment, Fedexer.recipient(@user.name, @user.addresses.first, @user.phones.first.number), @packages, 'FEDEX_2_DAY', Fedexer.default_shipping_details) 
        rate.should be_an_instance_of(Fedex::Rate)
      end

      it 'gets a standard express rate' do
        rate = Fedexer.get_rate(Fedexer.shipment, Fedexer.recipient(@user.name, @user.addresses.first, @user.phones.first.number), @packages, 'FEDEX_EXPRESS_SAVER', Fedexer.default_shipping_details) 
        rate.should be_an_instance_of(Fedex::Rate)
      end

      context 'with multiple packages' do
        before do
         @packages = [
            {
              weight: {units: 'LB', value: 2},
              dimensions: {length: 10, width: 5, height: 4, units: 'IN'}
            },
            {
              weight: {units: 'LB', value: 4},
              dimensions: {length: 10, width: 5, height: 4, units: 'IN'}
            }
          ]
        end

        it 'gets a Fedex Ground Rate' do
          rate = Fedexer.get_rate(Fedexer.shipment, Fedexer.recipient(@user.name, @user.addresses.first, @user.phones.first.number), @packages, 'STANDARD_OVERNIGHT', Fedexer.default_shipping_details) 
          rate.should be_an_instance_of(Fedex::Rate)
        end
      end

      context 'with a cart object' do
        before do
          @cart = FactoryGirl.create :anonymous_cart_ready_for_payments
        end

        it 'gets a rate' do
          rate = Fedexer.get_rate(Fedexer.shipment, Fedexer.recipient(@cart.first_name + " " + @cart.last_name, @cart.shipping_address, @cart.phone), Fedexer.sample_package, 'FEDEX_EXPRESS_SAVER', Fedexer.default_shipping_details) 
          rate.should be_an_instance_of(Fedex::Rate)
        end

        it 'gets a rate from the cart instance method' do
          rate = @cart.get_rate 'FEDEX_EXPRESS_SAVER'
          rate.should be_an_instance_of(Fedex::Rate)
        end
      end
    end
  end
end