package com.ourspace.common.config;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.UUID;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String id = "req_" + UUID.randomUUID().toString().replace("-", "");
        MDC.put("requestId", id);
        response.setHeader("X-Request-Id", id);
        try { chain.doFilter(request, response); }
        finally { MDC.remove("requestId"); }
    }
}
