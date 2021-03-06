require 'spec_helper'

describe 'Shopping Cart' do
  use_vcr_cassette

  before do
    @item = FactoryGirl.create :item, size_range: '4-9'
    @item_2 = FactoryGirl.create :item, name: 'item two', price: 50
    @item_backorder = FactoryGirl.create :item, name: 'item back order', price: 60, quantity: 0
  end

  context 'as an Anonymous User' do
    it 'adds a item to the cart' do
      visit item_path(@item.pretty_id)
      cart = Cart.last

      click_button 'Add to Cart'
      page.should have_content("#{@item.name.titleize} has been added to your cart")
      cart.reload
      cart.line_items.count.should == 1
      cart.line_items.map(&:item).include?(@item).should be
    end

    context 'with an item in a cart' do
      before do
        visit item_path(@item.pretty_id)
        select '7', from: 'line_item_size'
        click_button 'Add to Cart'
        @cart = Cart.last
      end

      it 'transfers cart to user after registration' do
        User.count.should == 0

        click_link 'Register'

        within '#registration-form' do
          fill_in 'user_first_name', with: 'Registered'
          fill_in 'user_last_name', with: 'User'
          fill_in 'user_email', with: 'registered-user@example.com'
          fill_in 'user_email_confirmation', with: 'registered-user@example.com'
          fill_in 'user_password', with: 'password'
          fill_in 'user_password_confirmation', with: 'password'

          click_button 'Register'
        end

        User.count.should == 1
        user = User.first

        @cart.reload
        @cart.user.should == user
      end
        
      it 'views the cart' do
        visit url_for([:root])

        click_link "Cart (#{@cart.line_items.count})"
        current_url.should == url_for([:cart])

        @cart.line_items.first.item.name.should be
        @cart.line_items.first.item.price.should be
        @cart.line_items.first.item.quantity.should be
        
        within('.item') do
          page.should have_content(@cart.line_items.first.item.description)
          page.should have_content(@cart.line_items.first.price)
          page.should have_content(@cart.line_items.first.quantity)
          page.should have_content(@cart.line_items.first.size)
        end
      end

      it 'removes an item from the cart' do
        visit url_for([:root])
  
        count = @cart.line_items.count
        click_link "Cart (#{@cart.line_items.count})"
        current_url.should == url_for([:cart])

        within "##{@cart.line_items.first.item.id}" do
          click_link 'Remove'
        end

        @cart.reload
        @cart.line_items.count.should == count - 1
      
      end

      it 'views the back order confirmation' do
        visit url_for([:root])
        @cart.line_items = nil
        @cart.reload

        visit item_path(@item_backorder.pretty_id)
        click_button 'Add to Cart'
        @cart.reload
        click_link "Cart (#{@cart.line_items.count})"
        current_url.should == url_for([:cart])

        page.should have_content(@item_backorder.backorder_notes)
        
        @cart.line_items = nil
        visit item_path(@item.pretty_id)
        click_button 'Add to Cart'
        @cart.reload
        click_link "Cart (#{@cart.line_items.count})"

        page.should_not have_content(@item.backorder_notes)
      end
  
      context 'starts the checkout process' do
        before do
          click_link "Cart (#{@cart.line_items.count})"
          click_button 'Next'
          current_url == url_for([:checkout])
          click_button 'Next'
        end

        it 'validates shipping address line 1' do
          page.should have_content("Address line 1 can't be blank")
          fill_in 'cart_shipping_address_address_1', with: 'W. side foo'
          click_button 'Next'
          page.should_not have_content("Address line 1 can't be blank")
        end

        it 'validates shipping address city' do
          page.should have_content("City can't be blank")
          fill_in 'cart_shipping_address_city', with: 'la'
          click_button 'Next'
          page.should_not have_content("City can't be blank")
        end

        it 'validates shipping address postal code' do
          page.should have_content("Postal Code can't be blank")
          fill_in 'cart_shipping_address_postal_code', with: '34567'
          click_button 'Next'
          page.should_not have_content("Postal Code can't be blank")
        end

        it 'validates email' do
          page.should have_content("Email can't be blank")
          fill_in 'cart_email', with: 'd'
          click_button 'Next'
          page.should have_content("d is not a proper email")
          page.should_not have_content("Email can't be blank")
          fill_in 'cart_email', with: 'thejoker@deepwoodsbrigade.com'
          click_button 'Next'
          page.should_not have_content("d is not a proper email")
          page.should_not have_content("Email can't be blank")
        end

        it 'validates phone' do
          page.should have_content("Phone can't be blank")
          fill_in 'cart_phone', with: '1'
          click_button 'Next'

          page.should have_content('1 is not a proper phone number. Example: (231)775-1289')
          page.should_not have_content("Phone can't be blank")

          fill_in 'cart_phone', with: '2319203456'
          click_button 'Next'
          page.should_not have_content('1 is not a proper phone number, Example: (231)775-1289')
          page.should_not have_content("Phone can't be blank")         
        end

        it 'validates first name' do
          page.should have_content("First name can't be blank")
          fill_in 'cart_first_name', with: 'george'
          click_button 'Next'
          page.should_not have_content("First name can't be blank")
        end

        it 'validates last name' do
          page.should have_content("Last name can't be blank")
          fill_in 'cart_last_name', with: 'omallie'
          click_button 'Next'
          page.should_not have_content("Last name can't be blank")
        end

        it 'fills in the Shipping Address, name, email, phone', js: true do
          @cart.shipping_address.should_not be

          fill_in 'cart_first_name', with: 'Anonymous'
          fill_in 'cart_last_name', with: 'User'
          fill_in 'cart_shipping_address_address_1', with: '25 Raglan Street, Ste. 20'
          fill_in 'cart_shipping_address_city', with: 'TORONTO'
          fill_in 'cart_shipping_address_postal_code', with: 'M5V 2Z9'
          
          select 'Canada', from: 'cart_shipping_address_country'
          select 'Ontario', from: 'cart_shipping_address_province'

          fill_in 'cart_email', with: 'bugsbunny@gmail.com'
          fill_in 'cart_phone', with: '2314567890'

          click_button 'Next'


          @cart.reload
          @cart.shipping_address.address_1.should == '25 Raglan Street, Ste. 20'
          @cart.shipping_address.city.should == 'TORONTO'
          @cart.shipping_address.province.should == 'ON'
          @cart.shipping_address.postal_code.should == 'M5V 2Z9'
          @cart.shipping_address.country.should == 'CA'
          @cart.email.should == 'bugsbunny@gmail.com'  
          @cart.phone.should == '2314567890'
          @cart.current_stage.should == 'shipping'
        end

        it 'removes an item' do
          count = @cart.line_items.count
          within "##{@cart.line_items.first.item.id}" do
            click_link 'Remove'
          end

          @cart.reload
          @cart.line_items.count.should == count - 1
        end

        it 'shows the backorder confirmation' do
          visit item_path(@item_backorder.pretty_id)
          click_button 'Add to Cart'
          @cart.reload
          visit url_for([:checkout])

          @cart.line_items.count.should == 2
          page.should have_content(@item_backorder.backorder_notes)
        end

        context 'with a shipping address', js:true do
          before do
            visit '/cart/checkout'
            fill_in 'cart_first_name', with: 'Anonymous'
            fill_in 'cart_last_name', with: 'User'
            fill_in 'cart_shipping_address_address_1', with: '2235 S 33 1/2 RD'
            fill_in 'cart_shipping_address_city', with: 'Cadillac'
            fill_in 'cart_shipping_address_postal_code', with: '49601'
            select  'United States', from: 'cart_shipping_address_country'
            select  'Michigan', from: 'cart_shipping_address_province'
            fill_in 'cart_email', with: 'bugsbunny@gmail.com'
            fill_in 'cart_phone', with: '2314567890'
            click_button 'Next'
          end

          it 'selects a shipping option' do
            select 'Ups Ground', from: 'cart_shipping_type'
            click_button 'Next'

            @cart.reload
            @cart.shipping_type.should == 'UPS-03' #or something like that
          end

          it 'selects a ups shipping option' do
            select 'Ups Ground', from: 'cart_shipping_type'
            click_button 'Next'

            @cart.reload
            @cart.shipping_type.should == 'UPS-03'
          end
        end

        context 'with an international shipping address', js:true do
          before do
            visit   '/cart/checkout'
            fill_in 'cart_first_name', with: 'Anonymous'
            fill_in 'cart_last_name', with: 'User'
            fill_in 'cart_shipping_address_address_1', with: '25 Raglan Street, Ste. 20'
            fill_in 'cart_shipping_address_city', with: 'TORONTO'
            fill_in 'cart_shipping_address_postal_code', with: 'M5V 2Z9'
            select  'Canada', from: 'cart_shipping_address_country'
            select  'Ontario', from: 'cart_shipping_address_province'
            fill_in 'cart_email', with: 'bugsbunny@gmail.com'
            fill_in 'cart_phone', with: '2314567890'
            click_button 'Next'
          end

          it 'selects a shipping option' do
            select 'Ups Ground', from: 'cart_shipping_type'
            click_button 'Next'

            @cart.reload
            @cart.shipping_type.should == 'UPS-03' #or something like that
          end
        end

        context 'paying for cart' do
          before do
            @cart = FactoryGirl.create :anonymous_cart_ready_for_payments
            page.set_rack_session(:cart_id => @cart.id)
            visit url_for([:pay])
          end

          context 'and validating credit card' do
            before do
              click_button 'Next'
            end

            it 'validates number' do
              page.should have_content("Number can't be blank")
              fill_in 'cart_credit_card_attributes_number', with: '4111111111111111'
              click_button 'Next'
              page.should_not have_content("Card number can't be blank")
            end

            it 'validates ccv' do
              page.should have_content("Ccv can't be blank")
              fill_in 'cart_credit_card_attributes_ccv', with: '111'
              click_button 'Next'
              page.should_not have_content("Ccv can't be blank")
            end

            it 'validates name' do
              page.should have_content("Name can't be blank")
              fill_in 'cart_credit_card_attributes_name', with: 'billing name'
              click_button 'Next'
              page.should_not have_content("Name can't be blank")
            end

            it 'validates billing address' do
              cart = FactoryGirl.create :anonymous_cart_ready_for_billing_address
              page.set_rack_session(:cart_id => cart.id)
              visit url_for([:pay])

              cart.billing_address.should_not be

              fill_in 'cart_billing_address_attributes_address_1', with: '3456 S. gigiidy RD'
              fill_in 'cart_billing_address_attributes_city', with: 'goo'
              fill_in 'cart_billing_address_attributes_province', with: 'MI'
              fill_in 'cart_billing_address_attributes_postal_code', with: '45637'
              fill_in 'cart_billing_address_attributes_country', with: 'US'

              click_button 'Next'

              cart.reload
              cart.billing_address.should be
              cart.billing_address.address_1.should == '3456 S. gigiidy RD'
              cart.billing_address.city.should == 'goo'
              cart.billing_address.province.should == 'MI'
              cart.billing_address.postal_code.should == '45637'
              cart.billing_address.country.should == 'US'
            end
          end

          context 'with valid card' do
            before do
              @cart = FactoryGirl.create :anonymous_cart_ready_for_billing_address
              page.set_rack_session cart_id: @cart.id
              visit url_for([:pay])
              fill_in 'cart_credit_card_attributes_number', with: '4111111111111111'
              fill_in 'cart_credit_card_attributes_ccv', with: '111'
              fill_in 'cart_credit_card_attributes_name', with: 'billing name'
              fill_in 'cart_billing_address_attributes_address_1', with: '3456 S. gigiidy RD'
              fill_in 'cart_billing_address_attributes_city', with: 'goo'
              fill_in 'cart_billing_address_attributes_province', with: 'MI'
              fill_in 'cart_billing_address_attributes_postal_code', with: '45637'
              fill_in 'cart_billing_address_attributes_country', with: 'US'
              select '9', from: 'cart_credit_card_attributes_month'
              select '17', from: 'cart_credit_card_attributes_year'
            end

            it 'processes payment' do
              click_button 'Next'
              current_url.should == url_for(:summary)

              @cart.reload
              @cart.order.purchased.should be
            end

            it 'shows an order summary' 
          end

          context 'with an order' do
            before do
              @cart = FactoryGirl.create :anonymous_cart_ready_for_billing_address
            end

            it 'views the summary' do
              #Fedex Rates are causing other test to fail
              visit url_for([:pay])
              fill_in 'cart_credit_card_attributes_number', with: '4111111111111111'
              fill_in 'cart_credit_card_attributes_ccv', with: '111'
              fill_in 'cart_credit_card_attributes_name', with: 'billing name'
              click_button 'Next'
              current_url.should == url_for([:summary])
                
              page.should have_content(@cart.first_name)
              page.should have_content(@cart.last_name)
              page.should have_content(@cart.shipping_address.to_single_line)
              @cart.line_items.each do |item| 
                page.should have_content(item.name)
                page.should have_content(item.price)
              end
              #page.should have_content(@cart.get_rate(@cart.shipping_type).total_net_charge)
             # page.should have_content(@cart.total)
              @cart.shipping_type = 'Ups Ground'
            end
          end
        end
      end
    end
  end

  context 'as a registered user' do
    before do
      @user    = FactoryGirl.create :web_user_with_address
    end

    context 'with an item in an anonymous cart' do
      before do
        visit item_path(@item.pretty_id)
        @cart = Cart.last
        click_button 'Add to Cart'
      end

      it 'transfers anonymous cart to logged in user' do
        fill_in 'user_email', with: @user.email
        fill_in 'user_password', with: 'password'

        click_button 'Login'

        @cart.reload
        @cart.user.should == @user
      end

      context 'starts the checkout process' do
        before do
          @user2 = FactoryGirl.create :user_with_phone_address
          @address = @user2.addresses.first
          login_with_dh('dh@example.com', 'password')
          click_link 'Check Out'
          current_url == url_for([:checkout])
        end

        it 'shows the cart in the check out process' do
          page.should have_content(@item.description)
          page.should have_content(@item.price)
        end

        it 'picks a shipping address' do
          page.should_not have_content ('cart_first_name')
          page.should_not have_content ('cart_last_name')
          page.should_not have_content ('cart_shipping_address_address_1')
          page.should_not have_content ('cart_shipping_address_city')
          page.should_not have_content ('cart_shipping_address_postal_code')
          page.should_not have_content ('cart_email')
          page.should_not have_content ('cart_phone')

          page.should have_content(@address.to_single_line)
          choose("cart_shipping_address_#{@address.id}")
          click_button 'Next'

          current_url.should == url_for([:shipping])

          @cart.reload
          @cart.shipping_address.to_single_line.should == @address.to_single_line
        end

        context 'with a shipping address' do
          before do
            choose("cart_shipping_address_#{@address.id}")
            click_button 'Next'
          end

          it 'picks Fedex shipping option' do
            current_url.should == url_for([:shipping])
            select 'Fed Ex Ground Home Delivery', from: 'cart_shipping_type'
            click_button 'Next'

            current_url.should == url_for([:pay])
            @cart.reload
            @cart.shipping_type.should == 'FEDEX-GROUND_HOME_DELIVERY' #or something like that
            @cart.total.should == @cart.subtotal + @cart.tax + @cart.shipping_options[@cart.shipping_type.to_sym][:price]
          end

          it 'picks UPS shipping option' do
            current_url.should == url_for([:shipping])
            
            select 'Ups Ground', from: 'cart_shipping_type'
            click_button 'Next'

            current_url.should == url_for([:pay])
            @cart.reload
            @cart.shipping_type.should == 'UPS-03' #or something like that
            @cart.total.should == @cart.subtotal + @cart.tax + @cart.shipping_options[@cart.shipping_type.to_sym][:price]
          end
        end
      end
      
      context 'with a previous cart' do
        before do
          @old_cart = FactoryGirl.create :cart, user: @user
          @old_cart.line_items.create item: @item_2
        end

        it 'merges anonymous cart with previous cart' do
          @user.reload
          @user.cart.should == @old_cart

          fill_in 'user_email', with: @user.email
          fill_in 'user_password', with: 'password'

          click_button 'Login'

          @user.reload
          @user.cart.should == @cart

          @cart.reload
          @cart.user.should == @user
          
          @cart.line_items.count.should == 2
          @cart.line_items.map(&:item).include?(@item_2).should be
        end
      end
    end
  end
end
