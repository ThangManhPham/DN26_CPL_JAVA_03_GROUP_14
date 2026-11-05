package com.ourspace.couplespace;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.couplespace.repository.EventRepository;
import com.ourspace.couplespace.service.CalendarService;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.service.ActiveCoupleAccess;
import jakarta.validation.Validator;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class CalendarTimezoneTests {
    @Test void counterUsesLocalCalendarDateAcrossMidnightInsteadOfUtcDate() {
        var user = UUID.randomUUID();
        var couple = new CoupleEntity();
        couple.setAnniversaryDate(LocalDate.of(2026, 10, 31));
        var access = mock(ActiveCoupleAccess.class);
        when(access.require(user)).thenReturn(couple);
        var service = new CalendarService(access, mock(EventRepository.class),
            Clock.fixed(Instant.parse("2026-11-01T00:30:00Z"), ZoneOffset.UTC),
            new ObjectMapper(), mock(Validator.class));
        assertThat(service.space(user, "Asia/Ho_Chi_Minh").daysTogether()).isEqualTo(1);
        assertThat(service.space(user, "America/Los_Angeles").daysTogether()).isZero();
        assertThat(service.space(user, "+14:00").anniversaryDate()).isEqualTo(LocalDate.of(2026, 10, 31));
    }

    @Test void dstDayCountsAsOneCalendarDayEvenThoughOnly23HoursElapsed() {
        var user = UUID.randomUUID();
        var couple = new CoupleEntity();
        couple.setAnniversaryDate(LocalDate.of(2026, 3, 8));
        var access = mock(ActiveCoupleAccess.class);
        when(access.require(user)).thenReturn(couple);
        var service = new CalendarService(access, mock(EventRepository.class),
            Clock.fixed(Instant.parse("2026-03-09T04:00:00Z"), ZoneOffset.UTC),
            new ObjectMapper(), mock(Validator.class));
        assertThat(service.space(user, "America/New_York").daysTogether()).isEqualTo(1);
    }
}
