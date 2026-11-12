package com.ourspace.couplespace.service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

/** Civil-date reminder. February 29 is observed on February 28 in non-leap years. */
public record AnniversaryReminder(LocalDate occursOn, long daysUntil, int yearsTogether) {
    public static AnniversaryReminder next(LocalDate anniversary, LocalDate today) {
        if (anniversary == null) return null;
        int year = Math.max(today.getYear(), anniversary.getYear() + 1);
        LocalDate next = anniversary.withYear(year);
        if (next.isBefore(today)) next = anniversary.withYear(++year);
        return new AnniversaryReminder(next, ChronoUnit.DAYS.between(today, next), year - anniversary.getYear());
    }
}
