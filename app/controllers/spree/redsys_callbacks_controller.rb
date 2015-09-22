module Spree
  class RedsysCallbacksController < Spree::BaseController

    skip_before_filter :verify_authenticity_token

    #ssl_required

    def redsys_notify
      logger.info "==== REDSYS#NOTIFY ==== order##{params[:order_id]} params# #{params.inspect}"
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      if check_signature
        payment_upgrade
        @order.updater.update_payment_total
      else
        payment_upgrade
      end
      render :nothing => true
    end 

    # Handle the incoming user
    def redsys_confirm
      logger.info "==== REDSYS#CONFIRM ==== order##{params[:order_id]} params# #{params.inspect}"
      @order ||= Spree::Order.find_by_number!(params[:order_id])
      if check_signature
        unless @order.payments.any?(&:completed?)
          payment_upgrade
          @order.updater.update_payment_total
        end
        @order.next
        if @order.completed?
          flash.notice = Spree.t(:order_processed_successfully)
          flash[:order_completed] = true
          session[:order_id] = nil
          redirect_to completion_route(@order)
        else
          flash[:error] = @order.errors.full_messages.join("\n")
          redirect_to checkout_state_path(@order.state) and return
        end
      else
        flash[:alert] = Spree.t(:spree_gateway_error_flash_for_checkout)
        redirect_to checkout_state_path(@order.state)
      end
    end

    def redsys_error
      logger.info "==== REDSYS#ERROR ==== order##{params[:order_id]} params# #{params.inspect}"
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
      else
        this_payment_params = redsys_payment_authorized? ? payment_params.merge(state: 'completed') : payment_params
        @payment.update_attributes(this_payment_params)
      end
      @order.reload
    end       

  end
end

