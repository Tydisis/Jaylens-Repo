package com.jaystewwtest.demo;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/visitors")
public class VisitorController {
    private final VisitorService visitorService;

    public VisitorController(VisitorService visitorService) {
        this.visitorService = visitorService;
    }

    @GetMapping
    public Map<String, Object> getVisitorStats(HttpServletRequest request, HttpServletResponse response) {
        visitorService.incrementTotal();

        boolean isNewVisitor = true;
        Cookie[] cookies = request.getCookies();
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if ("visitor_id".equals(cookie.getName())) {
                    isNewVisitor = false;
                    break;
                }
            }
        }

        if (isNewVisitor) {
            visitorService.incrementUnique();
            Cookie cookie = new Cookie("visitor_id", UUID.randomUUID().toString());
            cookie.setMaxAge(365 * 24 * 60 * 60);
            cookie.setPath("/");
            response.addCookie(cookie);
        }

        Map<String, Object> stats = new HashMap<>();
        stats.put("totalVisits", visitorService.getTotalVisitors());
        stats.put("uniqueVisitors", visitorService.getUniqueVisitors());
        stats.put("isNewVisitor", isNewVisitor);
        return stats;
    }
}
