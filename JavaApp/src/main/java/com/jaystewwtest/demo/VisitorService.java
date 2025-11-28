package com.jaystewwtest.demo;

import org.springframework.stereotype.Service;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class VisitorService {
    private final AtomicLong totalVisitors = new AtomicLong(0);
    private final AtomicLong uniqueVisitors = new AtomicLong(0);

    public long incrementTotal() {
        return totalVisitors.incrementAndGet();
    }

    public long incrementUnique() {
        return uniqueVisitors.incrementAndGet();
    }

    public long getTotalVisitors() {
        return totalVisitors.get();
    }

    public long getUniqueVisitors() {
        return uniqueVisitors.get();
    }
}
