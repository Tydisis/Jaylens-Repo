package com.jaystewwtest;

import com.jaystewwtest.store.StripePaymentService;

public class OrderService {
    public void placeOrder() {
        var paymentService = new StripePaymentService();
        paymentService.processPayment(10);
    }

}
