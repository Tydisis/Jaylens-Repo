package com.jaystewwtest.demo;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface GuestbookRepository extends JpaRepository<GuestbookEntry, Long> {
    List<GuestbookEntry> findTop10ByOrderByCreatedAtDesc();
}
