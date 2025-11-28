package com.jaystewwtest.store;

public class OrderService {
    public void placeOrder() {
        var paymentService = new StripePaymentService();
        paymentService.processPayment(10);
    }

}
