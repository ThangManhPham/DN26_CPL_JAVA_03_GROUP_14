package com.ourspace.couplespace;

import com.ourspace.couplespace.service.AnniversaryReminder;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class AnniversaryReminderTests {
    @Test void unsetDateHasNoReminderAndFirstReminderIsAfterOneYear() {
        assertThat(AnniversaryReminder.next(null, LocalDate.of(2026, 11, 10))).isNull();
        var date = LocalDate.of(2026, 11, 10);
        assertThat(AnniversaryReminder.next(date, date))
            .isEqualTo(new AnniversaryReminder(LocalDate.of(2027, 11, 10), 365, 1));
    }
    @Test void anniversaryTodayStaysTodayAndTomorrowRollsToNextYear() {
        var date = LocalDate.of(2020, 11, 10);
        assertThat(AnniversaryReminder.next(date, LocalDate.of(2026, 11, 10)))
            .isEqualTo(new AnniversaryReminder(LocalDate.of(2026, 11, 10), 0, 6));
        assertThat(AnniversaryReminder.next(date, LocalDate.of(2026, 11, 11)))
            .isEqualTo(new AnniversaryReminder(LocalDate.of(2027, 11, 10), 364, 7));
    }
    @Test void february29UsesFebruary28OnlyInNonLeapYears() {
        var date = LocalDate.of(2020, 2, 29);
        assertThat(AnniversaryReminder.next(date, LocalDate.of(2027, 2, 28)))
            .isEqualTo(new AnniversaryReminder(LocalDate.of(2027, 2, 28), 0, 7));
        assertThat(AnniversaryReminder.next(date, LocalDate.of(2028, 2, 28)))
            .isEqualTo(new AnniversaryReminder(LocalDate.of(2028, 2, 29), 1, 8));
        assertThat(AnniversaryReminder.next(date, LocalDate.of(2099, 3, 1)).occursOn())
            .isEqualTo(LocalDate.of(2100, 2, 28));
    }
    @Test void decemberCrossesIntoNextYear() {
        assertThat(AnniversaryReminder.next(LocalDate.of(2020, 1, 1), LocalDate.of(2026, 12, 31)))
            .isEqualTo(new AnniversaryReminder(LocalDate.of(2027, 1, 1), 1, 7));
    }
}
