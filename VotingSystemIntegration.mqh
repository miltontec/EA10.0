//+------------------------------------------------------------------+
//| VotingSystemIntegration.mqh                                      |
//| Helper functions for integrating Enhanced Voting System         |
//| into EA10.0                                                      |
//+------------------------------------------------------------------+
#ifndef VOTING_SYSTEM_INTEGRATION_MQH
#define VOTING_SYSTEM_INTEGRATION_MQH

#include <VotingStatistics.mqh>

//+------------------------------------------------------------------+
//| Capturar contexto actual del mercado para el voting system      |
//+------------------------------------------------------------------+
void CaptureEnhancedMarketContext(EnhancedMarketContext &context, RegimeDetectionSystem* regimeDetector = NULL) {
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
    if(atrHandle != INVALID_HANDLE) {
        if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0) {
            context.atr = atr[0];
        }
    }

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

    if(ma20Handle != INVALID_HANDLE && ma50Handle != INVALID_HANDLE) {
        if(CopyBuffer(ma20Handle, 0, 0, 1, ma20) > 0 && CopyBuffer(ma50Handle, 0, 0, 1, ma50) > 0) {
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
        }
    }

    // Calcular momentum
    double rsi[];
    ArraySetAsSeries(rsi, true);
    int rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    if(rsiHandle != INVALID_HANDLE) {
        if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) > 0) {
            context.momentum = (rsi[0] - 50) / 50; // Normalizado entre -1 y 1
        }
    }

    // Volumen
    long tickVolume[];
    ArraySetAsSeries(tickVolume, true);
    if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 20, tickVolume) > 0) {
        long avgVolume = 0;
        for(int i = 0; i < 20; i++) {
            avgVolume += tickVolume[i];
        }
        avgVolume /= 20;

        context.volumeRatio = (avgVolume > 0) ? (double)tickVolume[0] / avgVolume : 1.0;
    }

    // Spread y liquidez
    context.spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    context.liquidityScore = 1.0 / (1.0 + context.spread * 10000);

    // Detectar régimen usando RegimeDetectionSystem si está disponible
    if(regimeDetector != NULL) {
        RegimeInfo regimeInfo;
        if(regimeDetector.GetCurrentRegime(regimeInfo)) {
            context.regime = regimeInfo.regime;
            context.regimeConfidence = regimeInfo.confidence;
            context.regimeAge = regimeInfo.barsInRegime;
        }
    } else {
        context.regime = REGIME_RANGING;
        context.regimeConfidence = 0.5;
        context.regimeAge = 0;
    }

    // Generar ID único del contexto
    context.GenerateContextID();

    // Calcular complejidad
    context.CalculateComplexity();
}

//+------------------------------------------------------------------+
//| Calcular percentil del ATR                                      |
//+------------------------------------------------------------------+
double CalculateATRPercentile(double currentATR) {
    if(currentATR <= 0) return 50.0;

    double atrValues[];
    ArraySetAsSeries(atrValues, true);

    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(atrHandle == INVALID_HANDLE) return 50.0;

    if(CopyBuffer(atrHandle, 0, 0, 100, atrValues) <= 0) return 50.0;

    int countBelow = 0;
    for(int i = 0; i < 100; i++) {
        if(atrValues[i] < currentATR) countBelow++;
    }

    return (double)countBelow / 100.0 * 100.0;
}

//+------------------------------------------------------------------+
//| Convertir ENUM_VOTE_DIRECTION a ENUM_COMPONENT_TYPE             |
//+------------------------------------------------------------------+
ENUM_COMPONENT_TYPE VoteDirectionToComponentType(ENUM_VOTE_DIRECTION direction) {
    switch(direction) {
        case VOTE_STRONG_BUY:
        case VOTE_BUY:
            return COMPONENT_BULLISH;

        case VOTE_STRONG_SELL:
        case VOTE_SELL:
            return COMPONENT_BEARISH;

        case VOTE_NEUTRAL:
        default:
            return COMPONENT_NEUTRAL;
    }
}

//+------------------------------------------------------------------+
//| Convertir ENUM_COMPONENT_TYPE a ENUM_VOTE_DIRECTION             |
//+------------------------------------------------------------------+
ENUM_VOTE_DIRECTION ComponentTypeToVoteDirection(ENUM_COMPONENT_TYPE type, double strength = 0.7) {
    if(type == COMPONENT_BULLISH) {
        return (strength > 0.8) ? VOTE_STRONG_BUY : VOTE_BUY;
    } else if(type == COMPONENT_BEARISH) {
        return (strength > 0.8) ? VOTE_STRONG_SELL : VOTE_SELL;
    }
    return VOTE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Estructura para tracking de trades activos                      |
//+------------------------------------------------------------------+
struct EnhancedTradeInfo {
    ulong ticket;
    ENUM_VOTE_DIRECTION votes[8];
    double confidences[8];
    EnhancedMarketContext context;
    datetime openTime;
    double openPrice;

    void Initialize() {
        ticket = 0;
        for(int i = 0; i < 8; i++) {
            votes[i] = VOTE_NEUTRAL;
            confidences[i] = 0.0;
        }
        context.Initialize();
        openTime = 0;
        openPrice = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Guardar información del trade para feedback posterior           |
//+------------------------------------------------------------------+
void SaveEnhancedTradeInfo(EnhancedTradeInfo &trades[], ulong ticket,
                          ENUM_VOTE_DIRECTION votes[], double confidences[],
                          EnhancedMarketContext &context) {
    int size = ArraySize(trades);
    ArrayResize(trades, size + 1);

    trades[size].Initialize();
    trades[size].ticket = ticket;

    // Copiar votos y confianzas
    for(int i = 0; i < 8; i++) {
        trades[size].votes[i] = votes[i];
        trades[size].confidences[i] = confidences[i];
    }

    trades[size].context = context;
    trades[size].openTime = TimeCurrent();

    // Obtener precio de apertura
    if(PositionSelectByTicket(ticket)) {
        trades[size].openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    }
}

//+------------------------------------------------------------------+
//| Buscar y eliminar trade info por ticket                         |
//+------------------------------------------------------------------+
bool FindAndRemoveTradeInfo(EnhancedTradeInfo &trades[], ulong ticket, EnhancedTradeInfo &foundInfo) {
    for(int i = 0; i < ArraySize(trades); i++) {
        if(trades[i].ticket == ticket) {
            foundInfo = trades[i];

            // Eliminar del array
            for(int j = i; j < ArraySize(trades) - 1; j++) {
                trades[j] = trades[j + 1];
            }
            ArrayResize(trades, ArraySize(trades) - 1);

            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Actualizar performance del sistema de votación                  |
//+------------------------------------------------------------------+
void UpdateVotingSystemPerformance(CEnhancedAdaptiveVotingSystem* votingSystem,
                                  EnhancedTradeInfo &tradeInfo,
                                  double profit, bool won) {
    if(votingSystem == NULL) return;

    // Calcular métricas adicionales
    int bars = (int)((TimeCurrent() - tradeInfo.openTime) / PeriodSeconds(PERIOD_CURRENT));

    // MAE y MFE simplificados
    double mae = 0.0;
    double mfe = 0.0;

    if(PositionSelectByTicket(tradeInfo.ticket)) {
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        mae = MathAbs(tradeInfo.openPrice - currentPrice) * ((profit < 0) ? 1.5 : 0.5);
        mfe = MathAbs(profit);
    }

    // Actualizar performance de cada indicador que votó
    for(int i = 0; i < 8; i++) {
        if(tradeInfo.votes[i] != VOTE_NEUTRAL && tradeInfo.confidences[i] > 0.1) {
            votingSystem.UpdatePerformance(
                i,                      // ID del indicador
                tradeInfo.context,      // Contexto cuando se tomó la decisión
                tradeInfo.votes[i],     // Voto que dio
                won,                    // Si ganó o perdió
                profit,                 // Profit/Loss
                bars,                   // Duración en barras
                mae,                    // Maximum Adverse Excursion
                mfe                     // Maximum Favorable Excursion
            );
        }
    }
}

#endif // VOTING_SYSTEM_INTEGRATION_MQH
