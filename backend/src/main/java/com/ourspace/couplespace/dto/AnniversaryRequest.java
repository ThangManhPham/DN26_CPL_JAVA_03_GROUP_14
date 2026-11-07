package com.ourspace.couplespace.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record AnniversaryRequest(@NotNull LocalDate anniversaryDate) {}
