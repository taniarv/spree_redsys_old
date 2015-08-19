module Spree
  class RedsysCallbacksController < Spree::BaseController

    skip_before_filter :verify_authenticity_token

    #ssl_required

    def redsys_notify
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      if check_signature
        unless @order.state == "complete"
          order_upgrade
        end
        payment_upgrade
        @payment.complete!
      else
        payment_upgrade
      end
      render :nothing => true
    end 

    # Handle the incoming user
    def redsys_confirm
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      if check_signature && redsys_payment_authorized?
        # create checkout
        @order.payments.create!(payment_params.merge(:state => "completed"))
        @order.updater.update_payment_total

        unless @order.next
          flash[:error] = @order.errors.full_messages.join("\n")
          redirect_to checkout_state_path(@order.state) and return
        end

        if @order.completed?
          @current_order = nil
          flash.notice = Spree.t(:order_processed_successfully)
          flash['order_completed'] = true
          redirect_to completion_route(@order)
        else
          redirect_to checkout_state_path(@order.state)
        end
      else
        flash[:alert] = Spree.t(:spree_gateway_error_flash_for_checkout)
        redirect_to checkout_state_path(@order.state)
      end
    end

    def redsys_error
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      @order.update_attribute(:payment_state, 'failed')
      flash[:alert] = Spree.t(:spree_gateway_error_flash_for_checkout)
      redirect_to checkout_state_path(@order.state)
    end

    def redsys_credentials
      { :terminal_id   => payment_method.preferred_terminal_id,
        :commercial_id => payment_method.preferred_commercial_id,
        :secret_key    => payment_method.preferred_secret_key,
        :key_type      => payment_method.preferred_key_type }
    end

    def payment_method
      @payment_method ||= Spree::PaymentMethod.find(params[:payment_method_id])
    end

    def redsys_payment_authorized?
      params[:Ds_AuthorisationCode].present?
    end

    def check_signature
      return false if (params['Ds_Response'].blank? || params['Ds_Response'].to_s != "0000")
      str = params['Ds_Amount'].to_s +
            params['Ds_Order'].to_s +
            params['Ds_MerchantCode'].to_s +
            params['Ds_Currency'].to_s +
            params['Ds_Response'].to_s
      str += redsys_credentials[:secret_key]
      signature = Digest::SHA1.hexdigest(str)
      logger.debug "Spree::Redsys notify: Hour #{params['Ds_Hour'].to_s}, order_id: #{params[:order_id].to_s}, 
          Calculated signature: #{signature.upcase}, Ds_Signature: #{params['Ds_Signature'].to_s}"
      return (signature.upcase == params['Ds_Signature'].to_s.upcase)
    end    

    def completion_route(order)
      order_path(order, :token => order.guest_token)
    end

    def payment_params
      {
        :source => Spree::RedsysCheckout.create({
          :ds_params => params.except(:payment_method_id).to_json
          }),
        :amount => @order.total,
        :payment_method => payment_method,
        :response_code => params['Ds_Response'].to_s,
        :avs_response => params['Ds_AuthorisationCode'].to_s
      }
    end

    def payment_upgrade
      @payment = Spree::Payment.find_by_order_id(@order)
      if @payment.nil?
        @payment = @order.payments.create(payment_params)
        @payment.started_processing!
      else
        @payment.update_attributes(payment_params)
      end
      @payment.process!
      @order.update(:considered_risky => 0)
    end       

    def order_upgrade
      @order.update(:state => "complete", :considered_risky => 1,  :completed_at => Time.now)
      # Since we dont rely on state machine callback, we just explicitly call this method for spree_store_credits
      if @order.respond_to?(:consume_users_credit, true)
        @order.send(:consume_users_credit)
      end
      @order.finalize!
    end

  end
end

