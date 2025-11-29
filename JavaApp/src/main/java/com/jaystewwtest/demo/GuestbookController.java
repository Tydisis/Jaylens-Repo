package com.jaystewwtest.demo;

import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/guestbook")
public class GuestbookController {
    
    private final GuestbookRepository repository;
    
    public GuestbookController(GuestbookRepository repository) {
        this.repository = repository;
    }
    
    @GetMapping
    public List<GuestbookEntry> getEntries() {
        return repository.findTop10ByOrderByCreatedAtDesc();
    }
    
    @PostMapping
    public GuestbookEntry addEntry(@RequestBody GuestbookEntry entry) {
        if (entry.getName() == null || entry.getName().trim().isEmpty()) {
            throw new IllegalArgumentException("Name is required");
        }
        if (entry.getMessage() == null || entry.getMessage().trim().isEmpty()) {
            throw new IllegalArgumentException("Message is required");
        }
        if (entry.getMessage().length() > 500) {
            throw new IllegalArgumentException("Message too long (max 500 characters)");
        }
        return repository.save(entry);
    }
}
