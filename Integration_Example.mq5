//+------------------------------------------------------------------+
//| Integration_Example.mq5 - Ejemplo de Integración                |
//| Cómo usar el nuevo VotingStatistics Enhanced en tu EA           |
//+------------------------------------------------------------------+

#include <VotingStatistics.mqh>

//+------------------------------------------------------------------+
//| Ejemplo de uso del Sistema de Votación Adaptativo Enhanced      |
//+------------------------------------------------------------------+

// Instancia global del sistema
CEnhancedAdaptiveVotingSystem* g_votingSystem;

//+------------------------------------------------------------------+
//| Inicialización del EA                                           |
//+------------------------------------------------------------------+
int OnInit() {
    // Crear instancia del sistema
    g_votingSystem = new CEnhancedAdaptiveVotingSystem();

    Print("Sistema de Votación Adaptativo Enhanced inicializado");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Función principal del EA                                         |
//+------------------------------------------------------------------+
void OnTick() {
    // 1. CAPTURAR CONTEXTO ACTUAL DEL MERCADO
    EnhancedMarketContext currentContext;
    CaptureMarketContext(currentContext);

    // 2. OBTENER PESOS DINÁMICOS PARA LOS INDICADORES
    EnhancedDynamicWeight weights[];
    g_votingSystem.GetDynamicWeights(weights, currentContext);

    // 3. RECOPILAR VOTOS DE CADA INDICADOR
    ENUM_VOTE_DIRECTION votes[8];
    double confidences[8];

    // Ejemplo: Support/Resistance
    votes[0] = GetSupportResistanceVote();
    confidences[0] = g_votingSystem.GetIndicatorRecommendation(0, currentContext, votes[0]);

    // Ejemplo: ML System
    votes[1] = GetMLSystemVote();
    confidences[1] = g_votingSystem.GetIndicatorRecommendation(1, currentContext, votes[1]);

    // Ejemplo: Momentum
    votes[2] = GetMomentumVote();
    confidences[2] = g_votingSystem.GetIndicatorRecommendation(2, currentContext, votes[2]);

    // Ejemplo: RSI
    votes[3] = GetRSIVote();
    confidences[3] = g_votingSystem.GetIndicatorRecommendation(3, currentContext, votes[3]);

    // Ejemplo: Volume
    votes[4] = GetVolumeVote();
    confidences[4] = g_votingSystem.GetIndicatorRecommendation(4, currentContext, votes[4]);

    // Los demás indicadores...
    votes[5] = VOTE_NEUTRAL;
    confidences[5] = 0.5;
    votes[6] = VOTE_NEUTRAL;
    confidences[6] = 0.5;
    votes[7] = VOTE_NEUTRAL;
    confidences[7] = 0.5;

    // 4. APLICAR PESOS A LAS CONFIANZAS
    for(int i = 0; i < 8; i++) {
        confidences[i] *= weights[i].finalWeight;
    }

    // 5. RESOLVER CONFLICTOS Y OBTENER DECISIÓN FINAL
    ENUM_VOTE_DIRECTION finalDecision = g_votingSystem.ResolveConflict(votes, confidences, 8);

    // 6. EJECUTAR TRADE SI HAY DECISIÓN
    if(finalDecision != VOTE_NEUTRAL) {
        ulong ticket = ExecuteTrade(finalDecision, currentContext);

        // Guardar información para feedback posterior
        if(ticket > 0) {
            SaveTradeInfo(ticket, votes, confidences, currentContext);
        }
    }

    // 7. ACTUALIZAR PERFORMANCE (en OnTradeTransaction o cuando se cierre el trade)
    // Ver función UpdatePerformanceAfterTrade() más abajo
}

//+------------------------------------------------------------------+
//| Capturar contexto actual del mercado                            |
//+------------------------------------------------------------------+
void CaptureMarketContext(EnhancedMarketContext &context) {
    context.Initialize();

    // Información temporal
    MqlDateTime dt;
    TimeCurrent(dt);
    context.timestamp = TimeCurrent();
    context.hourGMT = dt.hour;
    context.dayOfWeek = dt.day_of_week;
    context.weekOfMonth = (dt.day - 1) / 7 + 1;
    context.monthOfYear = dt.mon;

    // Determinar sesión
    if(context.hourGMT >= 0 && context.hourGMT < 8) {
        context.session = SESSION_ASIA;
    } else if(context.hourGMT >= 8 && context.hourGMT < 13) {
        context.session = SESSION_LONDON;
    } else if(context.hourGMT >= 13 && context.hourGMT < 16) {
        context.session = SESSION_OVERLAP_EU_US;
    } else if(context.hourGMT >= 16 && context.hourGMT < 22) {
        context.session = SESSION_NY;
    } else {
        context.session = SESSION_OVERNIGHT;
    }

    // Calcular ATR y volatilidad
    double atr[];
    ArraySetAsSeries(atr, true);
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    CopyBuffer(atrHandle, 0, 0, 1, atr);
    context.atr = atr[0];

    // Determinar nivel de volatilidad basado en percentiles históricos
    context.atrPercentile = CalculateATRPercentile(context.atr);

    if(context.atrPercentile < 20) {
        context.volatility = VOL_ULTRA_LOW;
    } else if(context.atrPercentile < 40) {
        context.volatility = VOL_LOW;
    } else if(context.atrPercentile < 60) {
        context.volatility = VOL_MEDIUM;
    } else if(context.atrPercentile < 80) {
        context.volatility = VOL_HIGH;
    } else {
        context.volatility = VOL_EXTREME;
    }

    // Determinar dirección del mercado
    double ma20[], ma50[];
    ArraySetAsSeries(ma20, true);
    ArraySetAsSeries(ma50, true);

    int ma20Handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    int ma50Handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);

    CopyBuffer(ma20Handle, 0, 0, 1, ma20);
    CopyBuffer(ma50Handle, 0, 0, 1, ma50);

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double priceVsMA20 = (currentPrice - ma20[0]) / ma20[0] * 100;
    double ma20VsMA50 = (ma20[0] - ma50[0]) / ma50[0] * 100;

    if(priceVsMA20 > 2 && ma20VsMA50 > 1) {
        context.direction = DIR_STRONG_BULLISH;
    } else if(priceVsMA20 > 0.5 && ma20VsMA50 > 0) {
        context.direction = DIR_BULLISH;
    } else if(priceVsMA20 < -2 && ma20VsMA50 < -1) {
        context.direction = DIR_STRONG_BEARISH;
    } else if(priceVsMA20 < -0.5 && ma20VsMA50 < 0) {
        context.direction = DIR_BEARISH;
    } else {
        context.direction = DIR_NEUTRAL;
    }

    // Calcular momentum
    double rsi[];
    ArraySetAsSeries(rsi, true);
    int rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    CopyBuffer(rsiHandle, 0, 0, 1, rsi);
    context.momentum = (rsi[0] - 50) / 50; // Normalizado entre -1 y 1

    // Volumen
    long tickVolume[];
    ArraySetAsSeries(tickVolume, true);
    CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 20, tickVolume);

    long avgVolume = 0;
    for(int i = 0; i < 20; i++) {
        avgVolume += tickVolume[i];
    }
    avgVolume /= 20;

    context.volumeRatio = (avgVolume > 0) ? (double)tickVolume[0] / avgVolume : 1.0;

    // Spread y liquidez
    context.spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    context.liquidityScore = 1.0 / (1.0 + context.spread * 10000); // Score basado en spread

    // TODO: Detectar régimen con tu RegimeDetectionSystem
    context.regime = REGIME_RANGING; // Placeholder
    context.regimeConfidence = 0.7;

    // Generar ID único del contexto
    context.GenerateContextID();

    // Calcular complejidad
    context.CalculateComplexity();
}

//+------------------------------------------------------------------+
//| Calcular percentil del ATR                                      |
//+------------------------------------------------------------------+
double CalculateATRPercentile(double currentATR) {
    // Calcular percentil basado en histórico de 100 períodos
    double atrValues[];
    ArraySetAsSeries(atrValues, true);

    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    CopyBuffer(atrHandle, 0, 0, 100, atrValues);

    int countBelow = 0;
    for(int i = 0; i < 100; i++) {
        if(atrValues[i] < currentATR) countBelow++;
    }

    return (double)countBelow / 100.0 * 100.0;
}

//+------------------------------------------------------------------+
//| Obtener votos de cada indicador (ejemplos)                      |
//+------------------------------------------------------------------+
ENUM_VOTE_DIRECTION GetSupportResistanceVote() {
    // Tu lógica de Support/Resistance aquí
    // Este es solo un ejemplo
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double resistance = bid + 100 * _Point; // Ejemplo simplificado
    double support = bid - 100 * _Point;

    if(bid > resistance) return VOTE_SELL;
    if(bid < support) return VOTE_BUY;
    return VOTE_NEUTRAL;
}

ENUM_VOTE_DIRECTION GetMLSystemVote() {
    // Tu sistema ML aquí
    return VOTE_NEUTRAL;
}

ENUM_VOTE_DIRECTION GetMomentumVote() {
    // Ejemplo con momentum
    double mom[];
    ArraySetAsSeries(mom, true);
    int momHandle = iMomentum(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    CopyBuffer(momHandle, 0, 0, 1, mom);

    if(mom[0] > 100.5) return VOTE_BUY;
    if(mom[0] < 99.5) return VOTE_SELL;
    return VOTE_NEUTRAL;
}

ENUM_VOTE_DIRECTION GetRSIVote() {
    // Ejemplo con RSI
    double rsi[];
    ArraySetAsSeries(rsi, true);
    int rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    CopyBuffer(rsiHandle, 0, 0, 1, rsi);

    if(rsi[0] > 70) return VOTE_SELL;
    if(rsi[0] < 30) return VOTE_BUY;
    return VOTE_NEUTRAL;
}

ENUM_VOTE_DIRECTION GetVolumeVote() {
    // Ejemplo con volumen
    long volume[];
    ArraySetAsSeries(volume, true);
    CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 2, volume);

    if(volume[0] > volume[1] * 1.5) {
        // Alto volumen, verificar dirección del precio
        double close[];
        ArraySetAsSeries(close, true);
        CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, close);

        if(close[0] > close[1]) return VOTE_BUY;
        else return VOTE_SELL;
    }
    return VOTE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Ejecutar trade basado en decisión                               |
//+------------------------------------------------------------------+
ulong ExecuteTrade(ENUM_VOTE_DIRECTION decision, EnhancedMarketContext &context) {
    // Calcular tamaño de posición
    double lotSize = CalculateLotSize(context);

    // Preparar orden
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.symbol = _Symbol;
    request.volume = lotSize;
    request.magic = 123456;
    request.deviation = 10;

    if(decision == VOTE_BUY || decision == VOTE_STRONG_BUY) {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        request.sl = request.price - context.atr * 2;
        request.tp = request.price + context.atr * 3;
        request.comment = "VotingSystem BUY";
    } else if(decision == VOTE_SELL || decision == VOTE_STRONG_SELL) {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        request.sl = request.price + context.atr * 2;
        request.tp = request.price - context.atr * 3;
        request.comment = "VotingSystem SELL";
    }

    if(OrderSend(request, result)) {
        Print("✅ Orden ejecutada: ", result.order, " | Precio: ", request.price);
        return result.order;
    } else {
        Print("❌ Error al ejecutar orden: ", GetLastError());
        return 0;
    }
}

//+------------------------------------------------------------------+
//| Calcular tamaño de lote basado en contexto                      |
//+------------------------------------------------------------------+
double CalculateLotSize(EnhancedMarketContext &context) {
    // Ajustar tamaño según complejidad del mercado
    double baseLot = 0.01;

    // Reducir tamaño en mercados complejos
    if(context.contextComplexity > 0.7) {
        baseLot *= 0.5;
    } else if(context.contextComplexity < 0.3) {
        baseLot *= 1.5;
    }

    // Ajustar por volatilidad
    if(context.volatility == VOL_EXTREME) {
        baseLot *= 0.5;
    } else if(context.volatility == VOL_ULTRA_LOW) {
        baseLot *= 1.2;
    }

    return NormalizeDouble(baseLot, 2);
}

//+------------------------------------------------------------------+
//| Guardar información del trade para feedback                     |
//+------------------------------------------------------------------+
struct TradeInfo {
    ulong ticket;
    ENUM_VOTE_DIRECTION votes[8];
    double confidences[8];
    EnhancedMarketContext context;
    datetime openTime;
    double openPrice;
} g_activeTradeInfo[];

void SaveTradeInfo(ulong ticket, ENUM_VOTE_DIRECTION votes[],
                  double confidences[], EnhancedMarketContext &context) {
    int size = ArraySize(g_activeTradeInfo);
    ArrayResize(g_activeTradeInfo, size + 1);

    g_activeTradeInfo[size].ticket = ticket;
    ArrayCopy(g_activeTradeInfo[size].votes, votes);
    ArrayCopy(g_activeTradeInfo[size].confidences, confidences);
    g_activeTradeInfo[size].context = context;
    g_activeTradeInfo[size].openTime = TimeCurrent();
    g_activeTradeInfo[size].openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
}

//+------------------------------------------------------------------+
//| Actualizar performance cuando se cierra un trade                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result) {
    // Detectar cierre de posición
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal_type == DEAL_TYPE_SELL) {
        // Buscar info del trade
        for(int i = 0; i < ArraySize(g_activeTradeInfo); i++) {
            if(g_activeTradeInfo[i].ticket == trans.position) {
                UpdatePerformanceAfterTrade(i);

                // Eliminar de array
                ArrayRemove(g_activeTradeInfo, i, 1);
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Actualizar performance de indicadores después del trade         |
//+------------------------------------------------------------------+
void UpdatePerformanceAfterTrade(int tradeIndex) {
    TradeInfo* info = GetPointer(g_activeTradeInfo[tradeIndex]);

    // Seleccionar la posición
    if(!PositionSelectByTicket(info.ticket)) return;

    // Calcular resultado
    double profit = PositionGetDouble(POSITION_PROFIT);
    double openPrice = info.openPrice;
    double closePrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    bool won = (profit > 0);

    // Calcular métricas adicionales
    int bars = iBars(_Symbol, PERIOD_CURRENT, info.openTime, TimeCurrent());

    // MAE y MFE (simplificado - en producción necesitarías tracking completo)
    double mae = MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) -
                         PositionGetDouble(POSITION_PRICE_CURRENT)) *
                         ((profit < 0) ? 1 : 0.5);
    double mfe = MathAbs(profit) / PositionGetDouble(POSITION_VOLUME);

    // Actualizar performance de cada indicador que votó
    for(int i = 0; i < 8; i++) {
        if(info.votes[i] != VOTE_NEUTRAL && info.confidences[i] > 0.1) {
            // Solo actualizar si el indicador participó significativamente
            g_votingSystem.UpdatePerformance(
                i,                      // ID del indicador
                info.context,          // Contexto cuando se tomó la decisión
                info.votes[i],         // Voto que dio
                won,                   // Si ganó o perdió
                profit,                // Profit/Loss
                bars,                  // Duración en barras
                mae,                   // Maximum Adverse Excursion
                mfe                    // Maximum Favorable Excursion
            );
        }
    }

    // Mostrar estadísticas actualizadas
    if(MathMod(g_votingSystem.m_totalSystemTrades, 10) == 0) {
        Print(g_votingSystem.GetSystemStatistics());
    }
}

//+------------------------------------------------------------------+
//| Función de desinicialización                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    if(g_votingSystem != NULL) {
        // Guardar datos antes de cerrar
        g_votingSystem.SaveHistoricalData();

        delete g_votingSystem;
        g_votingSystem = NULL;
    }

    Print("Sistema de Votación Adaptativo Enhanced cerrado");
}

//+------------------------------------------------------------------+
//| Función para testing/debugging                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam,
                 const double& dparam, const string& sparam) {
    if(id == CHARTEVENT_KEYDOWN) {
        // Tecla 'S' para mostrar estadísticas
        if(lparam == 83) {
            Print(g_votingSystem.GetSystemStatistics());
        }
        // Tecla 'R' para forzar reset adaptativo
        else if(lparam == 82) {
            Print("Forzando reset adaptativo...");
            EnhancedMarketContext context;
            CaptureMarketContext(context);
            EnhancedDynamicWeight weights[];
            g_votingSystem.GetDynamicWeights(weights, context);
        }
    }
}
