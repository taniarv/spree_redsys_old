module Spree
  class RedsysCheckout < ActiveRecord::Base
    def payment
      Spree::Payment.find_by(source_id: self.id, source_type: self.class)      
    end

    def test_mode
      self.payment && self.payment.payment_method && self.payment.payment_method.preferences[:test_mode]
    end
  end
end