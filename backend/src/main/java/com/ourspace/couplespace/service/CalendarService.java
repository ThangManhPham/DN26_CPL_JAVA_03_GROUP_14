package com.ourspace.couplespace.service;

import com.ourspace.common.exception.ApiException;
import com.ourspace.couplespace.dto.*;
import com.ourspace.couplespace.entity.CoupleEvent;
import com.ourspace.couplespace.repository.EventRepository;
import com.ourspace.pairing.service.ActiveCoupleAccess;
import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.validation.Validator;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Service
@Transactional
public class CalendarService {
    private final ActiveCoupleAccess access;
    private final EventRepository events;
    private final Clock clock;
    private final ObjectMapper json;
    private final Validator validator;
    public CalendarService(ActiveCoupleAccess access, EventRepository events, Clock clock, ObjectMapper json, Validator validator) {
        this.access=access; this.events=events; this.clock=clock; this.json=json; this.validator=validator;
    }
    public record Space(UUID coupleId, LocalDate anniversaryDate, Long daysTogether, String timezone,
                        AnniversaryReminder reminder) {}
    public record EventPage(List<EventResponse> items, Integer nextPage) {}
    @Transactional(readOnly=true)
    public Space space(UUID user, String timezone) {
        var couple=access.require(user);
        var today=LocalDate.now(clock.withZone(zone(timezone)));
        var date=couple.getAnniversaryDate();
        return new Space(couple.getId(),date,date==null?null:ChronoUnit.DAYS.between(date,today),timezone,
            AnniversaryReminder.next(date, today));
    }
    public Space anniversary(UUID user, LocalDate date, String timezone) {
        var couple=access.require(user);
        var today=LocalDate.now(clock.withZone(zone(timezone)));
        if(date.isAfter(today) || date.isBefore(LocalDate.of(1900,1,1))) throw invalid("Anniversary must be between 1900-01-01 and today.");
        couple.setAnniversaryDate(date);
        return space(user,timezone);
    }
    @Transactional(readOnly=true)
    public EventPage list(UUID user, Instant from, Instant until, int page, int size) {
        var couple=access.require(user);
        if(from==null || until==null || !until.isAfter(from) || Duration.between(from,until).compareTo(Duration.ofDays(366))>0)
            throw invalid("Provide a date range from < until, at most 366 days.");
        if(page<0 || page>10000 || size<1 || size>100) throw invalid("page must be 0..10000 and size 1..100.");
        var result=events.inRange(couple.getId(),from,until,PageRequest.of(page,size));
        return new EventPage(result.map(EventResponse::of).toList(),result.hasNext()?page+1:null);
    }
    public EventResponse create(UUID user, EventRequest data) {
        var couple=access.require(user);
        validate(data);
        return EventResponse.of(events.saveAndFlush(new CoupleEvent(couple.getId(),user,data,clock.instant())));
    }
    @Transactional(readOnly=true)
    public EventResponse get(UUID user, UUID id) { return EventResponse.of(owned(user,id)); }
    public EventResponse patch(UUID user, UUID id, JsonNode patch) {
        var event=owned(user,id);
        if(!patch.isObject() || patch.isEmpty()) throw invalid("Provide at least one event field.");
        Set<String> fields=Set.of("title","description","startsAt","endsAt","timezone","version");
        patch.fieldNames().forEachRemaining(key->{if(!fields.contains(key)) throw invalid("Unsupported event field.");});
        checkVersion(event,patch.path("version"));
        ObjectNode merged=json.valueToTree(new EventRequest(event.title,event.description,event.startsAt,event.endsAt,event.timezone));
        patch.fields().forEachRemaining(field->{if(!field.getKey().equals("version")) merged.set(field.getKey(),field.getValue());});
        try {
            var data=json.treeToValue(merged,EventRequest.class);
            validate(data);
            event.apply(data,clock.instant());
            return EventResponse.of(events.saveAndFlush(event));
        } catch(com.fasterxml.jackson.core.JsonProcessingException ex) { throw invalid("Invalid event field format."); }
    }
    public void delete(UUID user, UUID id, long version) {
        var event=owned(user,id);
        if(version!=event.version) throw conflict();
        events.delete(event);
        events.flush();
    }
    private CoupleEvent owned(UUID user,UUID id) {
        var couple=access.require(user);
        return events.findByIdAndCoupleId(id,couple.getId()).orElseThrow(() ->
            new ApiException(HttpStatus.NOT_FOUND,"EVENT_NOT_FOUND","Event not found."));
    }
    private void checkVersion(CoupleEvent event,JsonNode version) {
        if(!version.isIntegralNumber() || !version.canConvertToLong()) throw invalid("version is required for updates.");
        if(version.longValue()!=event.version) throw conflict();
    }
    private void validate(EventRequest data) {
        if(!validator.validate(data).isEmpty()) throw invalid("Title is required (max 150); description max 2000; start, end and timezone are required.");
        zone(data.timezone());
        if(!data.endsAt().isAfter(data.startsAt())) throw invalid("endsAt must be after startsAt.");
        if(data.startsAt().isBefore(Instant.parse("1900-01-01T00:00:00Z")) ||
                data.endsAt().isAfter(Instant.parse("2101-01-01T00:00:00Z"))) throw invalid("Events must be between 1900 and 2100.");
    }
    private ZoneId zone(String value) {
        try { if(value==null || value.length()>64) throw new DateTimeException("zone"); return ZoneId.of(value); }
        catch(DateTimeException ex) { throw invalid("Invalid timezone."); }
    }
    private ApiException invalid(String message) { return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY,"VALIDATION_ERROR",message); }
    private ApiException conflict() { return new ApiException(HttpStatus.CONFLICT,"EVENT_CONFLICT","Event changed. Reload and retry."); }
}
