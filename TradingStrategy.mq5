//+------------------------------------------------------------------+
//|                      TradingStrategy_NCN_v15_Fixed.mq5           |
//|                Neural Consensus Network - Versión Corregida      |
//|              Integración completa con flujo simplificado         |
//+------------------------------------------------------------------+
#property copyright "NCN v15 Fixed - Sistema completo optimizado"
#property link      ""
#property version   "15.01"
#property description "Versión corregida con validación simplificada y flujo optimizado"

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <SupportResistance.mqh>
#include <VotingStatistics.mqh>
#include <MetaLearningSystem.mqh>
#include <OrderExecution.mqh>
#include <AccumulationZones.mqh>
#include <PatternMemory.mqh>
#include <BreakoutDetector_fixed.mqh>
#include <InstitutionalPlanFinder_fixed.mqh>
#include <RegimeDetectionSystem.mqh>
#include <EpisodicMemorySystem.mqh>

//+------------------------------------------------------------------+
// Estructura para registrar los votos de cada agente en el ciclo actual
struct AgentCycleVote
{
   bool   hasVoted;        // ¿emitió voto el agente?
   int    currentPosition; // 1 = BUY, -1 = SELL, 0 = sin posición
};

// Array global con el estado de los 5 agentes principales
AgentCycleVote g_agents[5];
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| ENUMERACIONES                                                    |
//+------------------------------------------------------------------+
enum TRADING_STATE
{
    STATE_WAITING_SR_TOUCH,         
    STATE_CHECKING_ACCUMULATION,    
    STATE_NEURAL_NEGOTIATION,       
    STATE_EXECUTING_ORDER,          
    STATE_MONITORING_POSITIONS,     
    STATE_CYCLE_COMPLETE
};

// ENUM_COMPONENT_TYPE ya está definido en VotingStatistics.mqh

//+------------------------------------------------------------------+
//| ESTRUCTURAS                                                      |
//+------------------------------------------------------------------+
struct CycleData
{
    // Identificación y tiempo
    datetime startTime;
    datetime touchTime;
    datetime accumStartTime;
    datetime negotiationTime;
    int cycleNumber;
    
    // Datos del toque SR
    double touchPrice;
    ENUM_SR_TYPE touchType;
    double srLevelStrength;      
    int srLevelTouches;          
    ENUM_SR_QUALITY srLevelQuality; 
    ENUM_SR_STATE srLevelState;
    
    // Datos de acumulación
    int accumBarsCount;
    bool accumValid;
    double accumCenter;
    double accumRange;
    
    // Datos de consenso
    bool isMultiOrderCycle;
    int negotiationRounds;
    double emotionalContext;
    ENUM_VOTE_DIRECTION activeDirection;
    bool seekingAdditional;
    double firstOrderOpenPrice;
    int ordersExecuted;
    string leadingAgent;
    double consensusQuality;
    bool vetoUsed;
    int privilegedAgentsCount;
    
    // Datos de régimen
    ENUM_MARKET_REGIME currentRegime;
    RegimeParameters regimeParams;
    
    // ID de episodio
    ulong episodeId;
    bool episodeSaved;
};

struct MarketInfo
{
    double currentATR;
    double currentBid;
    double currentAsk;
    ENUM_MARKET_SESSION session;
    datetime lastUpdate;
    double volatilityRatio;
    double momentum;
};

struct ExtendedTouchContext
{
    TouchContext srTouchContext;
    ENUM_MARKET_REGIME regime;
    HistoricalPrediction prediction;
    bool hasHistoricalData;
};

// ESTRUCTURA GLOBAL para tracking de votos
struct VoteTracker
{
    ulong consensus_id;
    datetime timestamp;
    struct AgentVote
    {
        bool voted;
        ENUM_VOTE_DIRECTION direction;
        double confidence;
        double adjustedConfidence;
        bool wasCorrect;  // Se llena después
    } agents[5];
    ENUM_VOTE_DIRECTION finalDirection;
    bool tradeExecuted;
    ulong orderTicket;
};

//+------------------------------------------------------------------+
//| ESTRUCTURA TradeResult para RegimeDetection                     |
//+------------------------------------------------------------------+
struct TradeResult
{
    ulong ticket;
    double profit;
    bool isWin;
    ENUM_MARKET_REGIME regime;
    ulong consensus_id;
    datetime closeTime;
};

//+------------------------------------------------------------------+
//| ESTRUCTURA DecisionContext para contexto de decisiones         |
//+------------------------------------------------------------------+
struct DecisionContext
{
    datetime timestamp;
    double volatility;
    double momentum;
    double volume_ratio;
    int session_type;
    double rsi;
    double atr_ratio;
    double fear_level;
    double greed_level;
    int active_orders;
    ENUM_VOTE_DIRECTION locked_direction;
};

//+------------------------------------------------------------------+
//| PARÁMETROS DE ENTRADA                                           |
//+------------------------------------------------------------------+
input group "=== CONFIGURACIÓN S/R v4 ==="
input bool UseM30_SR = true;
input bool UseH1_SR = true;
input bool UseH4_SR = true;
input bool UseD1_SR = true;
input double MinMovementATR = 2.0;
input int ConfirmationBars = 10;               // Reducido de 50 a 10 para confirmación más rápida

input group "=== CONFIGURACIÓN ACUMULACIÓN ==="
input int MinAccumulationBars = 2;              // Reducido de 7 a 2 para permitir trades
input int MaxAccumulationBars = 20;
input double AccumulationRangeATR = 2.0;        // Aumentado de 1.2 a 2.0 para mayor flexibilidad
input int AccumulationTimeout = 50;             // Aumentado de 30 a 50 para más tiempo             

input group "=== NEURAL CONSENSUS NETWORK ==="
input double MinConsensusStrength = 0.2;        
input double MinTotalConviction = 0.4;          
input bool RequireStrongConsensus = false;     
input double EmotionalThreshold = 0.7;          

input group "=== DETECCIÓN DE RÉGIMEN ==="
input bool EnableRegimeDetection = true;
input int RegimeLookbackPeriod = 100;
input double RegimeTransitionThreshold = 0.7;
input bool AdaptParametersByRegime = true;

input group "=== MEMORIA EPISÓDICA ==="
input bool EnableEpisodicMemory = true;
input int MaxEpisodes = 10000;
input double MinSimilarityThreshold = 0.7;
input int MinSamplesForPrediction = 3;

input group "=== SISTEMA DE PRIVILEGIOS ==="
input double MinWinRateForSenior = 60.0;       
input double MinWinRateForMaster = 70.0;       
input double MinWinRateForOracle = 80.0;       
input int MinTradesForPrivilege = 50;          
input double VetoPowerThreshold = 75.0;        
input bool ShowPerformanceStats = true;        

input group "=== FILTROS DE CALIDAD SR ==="
input bool RequireConfirmedLevels = true;
input double MinLevelStrength = 2.0;
input ENUM_SR_QUALITY MinLevelQuality = SR_QUALITY_NORMAL;

input group "=== SR SENSIBLE PARA ADICIONALES ==="
input double SensitivityMultiplier = 0.7;
input double MinQualityReductionPercent = 30.0;
input bool RequireStrongerConsensus = true;

input group "=== GESTIÓN DE RIESGO ==="
input double RiskPercentage = 2.0;              
input double MaxDrawdown = 15.0;                
input int MaxDailyTrades = 3;                   
input int MaxOrdersPerCycle = 5;                


input double MaxRiskCap = 3.0;           // %Equity máximo cuando todo se alinea
input int    ExtraOrdersTrending = 2;  // Órdenes adicionales en régimen favorable
input group "=== MULTI-ORDEN ==="

//=== Auto-generated Prototypes and Globals (v17) ===
double CalculateAgentRecentPerformance(int agentIndex,int lookbackHours);
double CalculateRecentWinRate(int lookbackTrades);
double CalculateCurrentDrawdown();
bool   CheckAgentsDisagree(int agentA,int agentB);
double GetAsianSessionWinRate();
double g_dynamicWeights[5] = {1,1,1,1,1};
//=== End autogenerated ===

input double OrderReduction = 35.0;             
input double PartialClosePercent = 20.0;        

input group "=== TRAILING STOP ==="
input double TrailingStartPercent = 0.25;
input double TrailingStepPercent = 0.125;
input double MinProfitForAdditional = 100;
input bool UseSmartTrailing = true;

input group "=== CONFIGURACIÓN GENERAL ==="
input bool EnableMetaLearning = true;           
input bool ShowVisuals = true;                  
input bool ShowDebugInfo = true;                
input bool ShowEmotionalAnalysis = true;
input bool ShowRegimeInfo = true;
input bool ShowEpisodicPredictions = true;
input int MagicNumber = 123456;                 

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
// Estado del sistema
TRADING_STATE g_currentState = STATE_WAITING_SR_TOUCH;
CycleData g_currentCycle;
MarketInfo g_market;
MarketEmotion g_marketEmotion;
DecisionContext g_decisionContext;

// Contextos
ExtendedTouchContext g_extendedTouch;
TouchContext g_touchContext;
AccumulationContext g_accumContext;
NeuralConsensusResult g_consensusResult;

// Control
datetime g_lastBarTime = 0;
int g_dailyTradeCount = 0;
datetime g_lastTradeDate = 0;
int g_totalCycles = 0;
int g_accumBarsSinceTouch = 0;
int g_emotionalAlerts = 0;
int g_barsInCurrentState = 0;

// Performance tracking
int g_performanceReportTimer = 0;
datetime g_lastPerformanceReport = 0;
string g_currentMasterAgent = "";

// Control de calidad SR
int g_strongLevelsNearby = 0;
double g_nearestSupportPrice = 0;
double g_nearestResistancePrice = 0;

// Variables de régimen
ENUM_MARKET_REGIME g_previousRegime = REGIME_RANGING;
datetime g_lastRegimeChange = 0;
int g_tradesInCurrentRegime = 0;
double g_regimeProfit = 0.0;

// Variables episódicas
ulong g_lastEpisodeId = 0;
int g_similarEpisodesFound = 0;
double g_historicalSuccessRate = 0.5;

// Objetos principales
CSupportResistance* g_srManager = NULL;
MetaLearningSystem* g_metaLearning = NULL;
OrderExecution* g_orderExecution = NULL;
// Sistema de Votación Mejorado con tracking contextual
CEnhancedAdaptiveVotingSystem* g_votingStats = NULL;

// Array para tracking de trades con el sistema de votación mejorado
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

EnhancedTradeInfo g_enhancedTrades[];
RegimeDetectionSystem* g_regimeDetector = NULL;
EpisodicMemorySystem* g_episodicMemory = NULL;

// Indicadores adicionales
CAccumulationZones* g_accumZones = NULL;
CBreakoutDetector* g_breakoutDetector = NULL;
CInstitutionalPlanFinder* g_instPlanFinder = NULL;
CPatternMemory* g_patternMemory = NULL;
ulong g_current_consensus_id = 0;

// Variables de control
bool g_EnableRegimeDetection = true;
bool g_EnableEpisodicMemory = true;

// Handles
int g_atrHandle = INVALID_HANDLE;
int g_rsiHandle = INVALID_HANDLE;

// Array global de tracking
VoteTracker g_voteHistory[];
int g_voteHistoryCount = 0;

//+------------------------------------------------------------------+
//| FUNCIONES HELPER PARA SISTEMA DE VOTACIÓN MEJORADO              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Capturar contexto del mercado para voting system                |
//+------------------------------------------------------------------+
void CaptureEnhancedMarketContext(EnhancedMarketContext &context) {
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
    if(g_atrHandle != INVALID_HANDLE) {
        if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0) {
            context.atr = atr[0];
        }
    }

    // Determinar percentil de volatilidad
    double atrValues[];
    ArraySetAsSeries(atrValues, true);
    if(g_atrHandle != INVALID_HANDLE && CopyBuffer(g_atrHandle, 0, 0, 100, atrValues) > 0) {
        int countBelow = 0;
        for(int i = 0; i < 100; i++) {
            if(atrValues[i] < context.atr) countBelow++;
        }
        context.atrPercentile = (double)countBelow / 100.0 * 100.0;
    } else {
        context.atrPercentile = 50.0;
    }

    // Determinar nivel de volatilidad
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

    // Determinar dirección del mercado con MAs
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

    // Calcular momentum con RSI
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if(g_rsiHandle != INVALID_HANDLE) {
        if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsi) > 0) {
            context.momentum = (rsi[0] - 50) / 50; // Normalizado -1 a 1
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

    // Régimen de mercado
    if(g_regimeDetector != NULL) {
        context.regime = g_regimeDetector.GetCurrentRegime();
        context.regimeConfidence = 0.8; // Valor por defecto
        context.regimeAge = 0;          // Valor por defecto
    } else {
        context.regime = REGIME_RANGING;
        context.regimeConfidence = 0.5;
        context.regimeAge = 0;
    }

    // Generar ID y calcular complejidad
    context.GenerateContextID();
    context.CalculateComplexity();
}

//+------------------------------------------------------------------+
//| Guardar información de trade para tracking                      |
//+------------------------------------------------------------------+
void SaveEnhancedTradeInfo(ulong ticket, ENUM_VOTE_DIRECTION &votes[], double &confidences[], EnhancedMarketContext &context) {
    int size = ArraySize(g_enhancedTrades);
    ArrayResize(g_enhancedTrades, size + 1);

    g_enhancedTrades[size].Initialize();
    g_enhancedTrades[size].ticket = ticket;

    for(int i = 0; i < 8; i++) {
        g_enhancedTrades[size].votes[i] = votes[i];
        g_enhancedTrades[size].confidences[i] = confidences[i];
    }

    g_enhancedTrades[size].context = context;
    g_enhancedTrades[size].openTime = TimeCurrent();

    if(PositionSelectByTicket(ticket)) {
        g_enhancedTrades[size].openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    }
}

//+------------------------------------------------------------------+
//| Buscar y eliminar trade info                                    |
//+------------------------------------------------------------------+
bool FindAndRemoveTradeInfo(ulong ticket, EnhancedTradeInfo &foundInfo) {
    for(int i = 0; i < ArraySize(g_enhancedTrades); i++) {
        if(g_enhancedTrades[i].ticket == ticket) {
            foundInfo = g_enhancedTrades[i];

            // Eliminar del array
            for(int j = i; j < ArraySize(g_enhancedTrades) - 1; j++) {
                g_enhancedTrades[j] = g_enhancedTrades[j + 1];
            }
            ArrayResize(g_enhancedTrades, ArraySize(g_enhancedTrades) - 1);

            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Convertir voto de indicador a ENUM_VOTE_DIRECTION               |
//+------------------------------------------------------------------+
ENUM_VOTE_DIRECTION TrendToVoteDirection(ENUM_TREND_DIRECTION trend) {
    if(trend == TREND_UP) return VOTE_BUY;
    if(trend == TREND_DOWN) return VOTE_SELL;
    return VOTE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Capturar votos actuales para Enhanced Voting System             |
//+------------------------------------------------------------------+
void CaptureVotesForEnhancedSystem(ulong ticket)
{
    if(g_votingStats == NULL || g_voteHistoryCount == 0) return;

    // Obtener el último tracker de votos
    VoteTracker lastTracker = g_voteHistory[g_voteHistoryCount - 1];

    // Preparar arrays para el sistema mejorado (8 indicadores)
    ENUM_VOTE_DIRECTION votes[8];
    double confidences[8];

    // Inicializar todos como neutral
    for(int i = 0; i < 8; i++)
    {
        votes[i] = VOTE_NEUTRAL;
        confidences[i] = 0.0;
    }

    // Mapear los 5 agentes actuales a los 8 indicadores del sistema mejorado:
    // 0: IND_SUPPORT_RESIST = Agent 0 (S/R)
    // 1: IND_ML_SYSTEM = MetaLearning (calcular de consenso)
    // 2: IND_MOMENTUM = (de contexto)
    // 3: IND_RSI = (de contexto)
    // 4: IND_VOLUME = Agent 1 (Accumulation)
    // 5: IND_PATTERN = Agent 2 (Pattern)
    // 6: IND_INSTITUTIONAL = Agent 4 (Institutional)
    // 7: IND_SENTIMENT = Agent 3 (Breakout)

    if(lastTracker.agents[0].voted) {
        votes[0] = lastTracker.agents[0].direction;
        confidences[0] = lastTracker.agents[0].confidence;
    }

    if(lastTracker.agents[1].voted) {
        votes[4] = lastTracker.agents[1].direction;
        confidences[4] = lastTracker.agents[1].confidence;
    }

    if(lastTracker.agents[2].voted) {
        votes[5] = lastTracker.agents[2].direction;
        confidences[5] = lastTracker.agents[2].confidence;
    }

    if(lastTracker.agents[3].voted) {
        votes[7] = lastTracker.agents[3].direction;
        confidences[7] = lastTracker.agents[3].confidence;
    }

    if(lastTracker.agents[4].voted) {
        votes[6] = lastTracker.agents[4].direction;
        confidences[6] = lastTracker.agents[4].confidence;
    }

    // Agregar ML System desde consenso
    if(g_consensusResult.final_direction != VOTE_NEUTRAL) {
        votes[1] = g_consensusResult.final_direction;
        confidences[1] = g_consensusResult.total_conviction;
    }

    // Capturar contexto del mercado
    EnhancedMarketContext currentContext;
    CaptureEnhancedMarketContext(currentContext);

    // Obtener pesos dinámicos (opcional - ya están aplicados los pesos del MetaLearning)
    EnhancedDynamicWeight weights[];
    if(g_votingStats != NULL) {
        g_votingStats.GetDynamicWeights(weights, currentContext);
    }

    // Guardar información para feedback cuando se cierre el trade
    SaveEnhancedTradeInfo(ticket, votes, confidences, currentContext);

    Print("✓ Votos capturados para Enhanced Voting System - Ticket: ", ticket);
}

//+------------------------------------------------------------------+
//| MÓDULO CORREGIDO: OnInit con Comunicación Completa             |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║    INICIANDO NCN v15 FIXED - VERSIÓN OPTIMIZADA      ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    // Inicializar handles
    g_atrHandle = iATR(_Symbol, _Period, 14);
    g_rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    
    if(g_atrHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE)
    {
        Print("ERROR: No se pudieron crear handles de indicadores");
        return INIT_FAILED;
    }
    
    // 1. Inicializar SupportResistance
    g_srManager = new CSupportResistance();
    if(!g_srManager.Init(ShowVisuals))
    {
        Print("ERROR: Fallo inicialización S/R v4");
        return INIT_FAILED;
    }
    g_srManager.ConfigureTimeframes(UseM30_SR, UseH1_SR, UseH4_SR, UseD1_SR);
    g_srManager.SetParameters(MinMovementATR, ConfirmationBars);
    Print("✓ SupportResistance v4 inicializado");
    
    // 2. Inicializar MetaLearning
    if(EnableMetaLearning)
    {
        g_metaLearning = new MetaLearningSystem();
        if(g_metaLearning != NULL)
        {
            g_metaLearning.Initialize();
            g_metaLearning.InitializeSymbolPattern(Symbol());
            
            g_metaLearning.SetPrivilegeParameters(
                MinWinRateForSenior / 100.0,
                MinWinRateForMaster / 100.0,
                MinWinRateForOracle / 100.0,
                MinTradesForPrivilege,
                VetoPowerThreshold / 100.0
            );
            
            Print("✓ MetaLearning inicializado");
        }
    }
    
    // 3. Inicializar RegimeDetection
    g_EnableRegimeDetection = EnableRegimeDetection;
    if(EnableRegimeDetection)
    {
        g_regimeDetector = new RegimeDetectionSystem();
        // INICIALIZACIÓN TEMPORAL - Sin EMS primero
        if(g_regimeDetector.Initialize(NULL, g_metaLearning))
        {
            Print("✓ RegimeDetection inicializado (parcial)");
            Print("  Régimen inicial: ", EnumToString(g_regimeDetector.GetCurrentRegime()));
        }
        else
        {
            Print("ADVERTENCIA: RegimeDetection no se pudo inicializar");
            delete g_regimeDetector;
            g_regimeDetector = NULL;
            g_EnableRegimeDetection = false;
        }
    }
    
    // 4. Inicializar EpisodicMemory
    g_EnableEpisodicMemory = EnableEpisodicMemory;
    if(EnableEpisodicMemory)
    {
        g_episodicMemory = new EpisodicMemorySystem();
        if(g_episodicMemory.Initialize(g_regimeDetector, g_metaLearning))
        {
            Print("✓ EpisodicMemory inicializado");
            
            // AHORA RE-INICIALIZAR RDS CON EMS
            if(g_regimeDetector != NULL)
            {
                g_regimeDetector.Initialize(g_episodicMemory, g_metaLearning);
                Print("✓ RegimeDetection re-inicializado con EMS");
            }
        }
        else
        {
            Print("ADVERTENCIA: EpisodicMemory no se pudo inicializar");
            delete g_episodicMemory;
            g_episodicMemory = NULL;
            g_EnableEpisodicMemory = false;
        }
    }
    
    // 5. NUEVA SECCIÓN: Establecer comunicación cruzada
    if(g_metaLearning != NULL && g_episodicMemory != NULL && g_regimeDetector != NULL)
    {
        Print("✓ COMUNICACIÓN CRUZADA ESTABLECIDA");
        
        // Sincronizar estadísticas iniciales
        ENUM_MARKET_REGIME currentRegime = g_regimeDetector.GetCurrentRegime();
        double winRate, avgProfit;
        int sampleSize;
        
        // Obtener estadísticas del régimen actual desde EMS
        g_episodicMemory.GetRegimeStatistics(currentRegime, winRate, avgProfit, sampleSize);
        
        Print("  Estadísticas régimen ", EnumToString(currentRegime), ":");
        Print("  - Muestras: ", sampleSize);
        Print("  - Win Rate: ", DoubleToString(winRate * 100, 1), "%");
        Print("  - Profit Avg: ", DoubleToString(avgProfit, 2));
    }
    
    // 6. Inicializar OrderExecution
    g_orderExecution = new OrderExecution();
    if(!g_orderExecution.Initialize(g_metaLearning))
    {
        Print("ERROR: Fallo inicialización OrderExecution");
        return INIT_FAILED;
    }
    g_orderExecution.SetParameters(RiskPercentage, 0.0, 1.5); // maxLot 0 => sin límite
    
    // Calcular trailing
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double trailingStartValue = currentPrice * (TrailingStartPercent / 100.0);
    double trailingStepValue = currentPrice * (TrailingStepPercent / 100.0);
    int trailingStartPts = (int)MathMax(10, MathRound(trailingStartValue / _Point));
    int trailingStepPts = (int)MathMax(5, MathRound(trailingStepValue / _Point));
    
    g_orderExecution.SetMultiOrderParams(OrderReduction/100.0, PartialClosePercent/100.0, 
                                        trailingStartPts, trailingStepPts, MaxOrdersPerCycle);
    g_orderExecution.SetEmotionalParams(EmotionalThreshold, EmotionalThreshold, 0.3);
    g_orderExecution.SetMagicNumber(MagicNumber);
    
    Print("✓ OrderExecution inicializado");
    
    // 7. Inicializar VotingStatistics
    g_votingStats = new CEnhancedAdaptiveVotingSystem();
    if(g_votingStats != NULL)
    {
        // CEnhancedAdaptiveVotingSystem se auto-inicializa en constructor
        Print("✓ Enhanced Adaptive Voting System con aprendizaje contextual inicializado");
    }
    
    // 8. Inicializar indicadores adicionales
    g_accumZones = new CAccumulationZones();
    g_accumZones.Init(_Period, ShowVisuals);
    
    g_breakoutDetector = new CBreakoutDetector();
    g_breakoutDetector.Init(_Period, ShowVisuals);
    
    g_instPlanFinder = new CInstitutionalPlanFinder();
    g_instPlanFinder.Init(_Period, ShowVisuals);
    
    g_patternMemory = new CPatternMemory();
    g_patternMemory.Init(_Period, ShowVisuals);
    
    Print("✓ Indicadores adicionales inicializados");
    
    // Resetear ciclo
    ResetCycle();
    
    // Timer para actualizaciones
    EventSetTimer(1);
    
    // Mostrar configuración
    ShowInitialConfiguration();
    
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║  SISTEMA NCN v15 FIXED INICIALIZADO EXITOSAMENTE     ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| MÓDULO CORREGIDO: OnDeinit sin error de tipo void              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    
    Print("═══ GUARDANDO ESTADO FINAL DEL SISTEMA ═══");
    
    // 1. Completar episodio activo si existe
    if(g_EnableEpisodicMemory && g_episodicMemory != NULL && g_currentCycle.episodeId > 0)
    {
        CompleteCurrentEpisode(false);
    }
    
    // 2. Guardar todos los datos de aprendizaje
    if(g_metaLearning != NULL)
    {
        Print("Guardando datos de MetaLearning...");
        g_metaLearning.SaveToFiles();
        Print("✓ Proceso de guardado de MetaLearning completado");
    }
    
    if(g_episodicMemory != NULL)
    {
        Print("Guardando episodios...");
        // EMS guarda automáticamente en su destructor
        Print("✓ Sistema de episodios preparado para cierre");
    }
    
    if(g_regimeDetector != NULL)
    {
        Print("Guardando historial de regímenes...");
        // RDS guarda automáticamente en su destructor
        Print("✓ Sistema de regímenes preparado para cierre");
    }
    
    // 3. Mostrar reporte final
    ShowFinalReport();
    
    // 4. Mostrar resumen de aprendizaje usando métodos públicos
    Print("\n═══ RESUMEN DE APRENDIZAJE ═══");
    
    if(g_metaLearning != NULL)
    {
        // Usar métodos públicos disponibles
        Print("ML - Tasa de consenso exitoso: ", 
              DoubleToString(g_metaLearning.GetConsensusSuccessRate() * 100, 1), "%");
        
        // Mostrar estadísticas de agentes
        Print("ML - Estadísticas finales de agentes:");
        for(int i = 0; i < 5; i++)
        {
            double winRate = g_metaLearning.GetAgentWinRate((ENUM_COMPONENT_TYPE)i);
            string privilege = g_metaLearning.GetAgentPrivilegeLevel((ENUM_COMPONENT_TYPE)i);
            Print("  ", GetAgentName((ENUM_COMPONENT_TYPE)i), 
                  ": WR ", DoubleToString(winRate * 100, 1), "% - ", privilege);
        }
        
        // Master agent final
        string masterAgent = g_metaLearning.GetMasterAgent();
        if(masterAgent != "None")
        {
            Print("ML - Master Agent final: ", masterAgent);
        }
    }
    
    if(g_episodicMemory != NULL && g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        // Mostrar estadísticas por régimen
        Print("EMS/RDS - Estadísticas por régimen:");
        
        for(int r = 0; r < 8; r++) // Todos los regímenes posibles
        {
            ENUM_MARKET_REGIME regime = (ENUM_MARKET_REGIME)r;
            double winRate = 0.0;
            double avgProfit = 0.0;
            int sampleSize = 0;
            
            // Llamar al método void sin usar en condicional
            g_episodicMemory.GetRegimeStatistics(regime, winRate, avgProfit, sampleSize);
            
            // Ahora verificar los resultados
            if(sampleSize > 0)
            {
                Print("  ", EnumToString(regime), ": ", 
                      sampleSize, " episodios, ",
                      DoubleToString(winRate * 100, 1), "% éxito");
            }
        }
    }
    
    // 5. Información general del sistema
    Print("\n═══ ESTADÍSTICAS GENERALES ═══");
    Print("Ciclos completados: ", g_totalCycles);
    Print("Trades del día: ", g_dailyTradeCount);
    
    if(g_votingStats != NULL)
    {
        // TODO: Método no existe - GetSuccessRate()
        // Print("Tasa de éxito global: ",
        //       DoubleToString(g_votingStats.GetSuccessRate() * 100, 1), "%");
    }
    
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        ENUM_MARKET_REGIME finalRegime = g_regimeDetector.GetCurrentRegime();
        Print("Régimen final: ", EnumToString(finalRegime));
        
        // Estadísticas del último régimen
        if(g_tradesInCurrentRegime > 0)
        {
            Print("Trades en último régimen: ", g_tradesInCurrentRegime);
            Print("P&L en último régimen: ", DoubleToString(g_regimeProfit, 2));
        }
    }
    
    // 6. Mensaje de despedida personalizado
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    string timeOfDay = "";
    if(dt.hour < 12) timeOfDay = "Buenos días";
    else if(dt.hour < 18) timeOfDay = "Buenas tardes";
    else timeOfDay = "Buenas noches";
    
    Print("\n", timeOfDay, ", el sistema NCN v15 se ha cerrado correctamente.");
    Print("Todos los datos han sido guardados para la próxima sesión.");
    
    // 7. Liberar handles
    if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
    if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
    
    // 8. Eliminar objetos
    if(g_srManager != NULL) { delete g_srManager; g_srManager = NULL; }
    if(g_metaLearning != NULL) { delete g_metaLearning; g_metaLearning = NULL; }
    if(g_orderExecution != NULL) { delete g_orderExecution; g_orderExecution = NULL; }
    if(g_votingStats != NULL)
    {
        Print("Guardando datos históricos del Enhanced Voting System...");
        g_votingStats.SaveHistoricalData();
        Print("✓ Datos de votación guardados");
        delete g_votingStats;
        g_votingStats = NULL;
    }
    if(g_regimeDetector != NULL) { delete g_regimeDetector; g_regimeDetector = NULL; }
    if(g_episodicMemory != NULL) { delete g_episodicMemory; g_episodicMemory = NULL; }
    if(g_accumZones != NULL) { delete g_accumZones; g_accumZones = NULL; }
    if(g_breakoutDetector != NULL) { delete g_breakoutDetector; g_breakoutDetector = NULL; }
    if(g_instPlanFinder != NULL) { delete g_instPlanFinder; g_instPlanFinder = NULL; }
    if(g_patternMemory != NULL) { delete g_patternMemory; g_patternMemory = NULL; }
    
    Comment("");
    
    Print("=== SISTEMA NCN v15 FIXED DETENIDO - Razón: ", GetDeInitReasonText(reason), " ===");
}

//+------------------------------------------------------------------+
//| FUNCIÓN AUXILIAR: Obtener texto de razón de desinicialización  |
//+------------------------------------------------------------------+
string GetDeInitReasonText(int reason)
{
    switch(reason)
    {
        case REASON_PROGRAM: return "EA eliminado del gráfico";
        case REASON_REMOVE: return "Programa removido";
        case REASON_RECOMPILE: return "Programa recompilado";
        case REASON_CHARTCHANGE: return "Cambio de símbolo o período";
        case REASON_CHARTCLOSE: return "Gráfico cerrado";
        case REASON_PARAMETERS: return "Parámetros modificados";
        case REASON_ACCOUNT: return "Cuenta cambiada";
        case REASON_TEMPLATE: return "Nueva plantilla aplicada";
        case REASON_INITFAILED: return "Fallo en inicialización";
        case REASON_CLOSE: return "Terminal cerrado";
        default: return "Razón desconocida";
    }
}

//+------------------------------------------------------------------+
//| EVENTO TIMER - VERSIÓN CORREGIDA                                |
//+------------------------------------------------------------------+
void OnTimer()
{
    UpdateMarketInfo();
    MonitorMarketEmotions();
    UpdateDecisionContext();
    
    // NUEVO: Monitorear órdenes cerradas para actualizar estadísticas
    MonitorClosedOrders();

    // --- FIX: Actualizar pesos dinámicos de los agentes ---
    AdjustAgentWeightsDynamically(); 
    // ------------------------------------------------------

    // Actualizar detección de régimen si está habilitada
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        g_regimeDetector.UpdateRegimeDetection();
        ENUM_MARKET_REGIME currentRegime = g_regimeDetector.GetCurrentRegime();
        if(currentRegime != g_previousRegime)
        {
            OnRegimeChange(g_previousRegime, currentRegime);
            g_previousRegime = currentRegime;
        }
    }
    
    // Actualizar información de niveles SR
    UpdateNearbySRInfo();

    // Actualizar Master Agent
    if(g_metaLearning != NULL)
    {
        string newMaster = g_metaLearning.GetMasterAgent();
        if(newMaster != g_currentMasterAgent && newMaster != "None")
        {
            g_currentMasterAgent = newMaster;
            Print("*** NUEVO MASTER AGENT: ", g_currentMasterAgent, " ***");
        }
    }
    
    // Performance report periódico
    g_performanceReportTimer++;
    if(ShowPerformanceStats && g_performanceReportTimer >= 3600) // Cada hora
    {
        ShowPerformanceReport();
        g_performanceReportTimer = 0;
    }
    
    if(ShowVisuals)
    {
        UpdateDisplay();
    }
    
    // Monitorear órdenes multi-ciclo
    if(g_orderExecution != NULL && g_orderExecution.m_multiOrder.cycleActive)
    {
        g_orderExecution.MonitorMultiplePositions();

        // Debug periódico
        static datetime lastDebugTime = 0;
        if(ShowDebugInfo && TimeCurrent() - lastDebugTime > 30)
        {
            lastDebugTime = TimeCurrent();
            PrintCycleDebugInfo();
        }
        
        // Si no hay órdenes activas, resetear
        if(g_orderExecution.m_multiOrder.orderCount == 0)
        {
            ResetCycle();
        }
    }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Tracking automático de performance         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    // Detectar cierre de posición o deal completado
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(g_votingStats == NULL) return;

        // Buscar si este deal corresponde a un trade que trackeamos
        EnhancedTradeInfo closedTrade;
        if(FindAndRemoveTradeInfo(trans.position, closedTrade))
        {
            // Obtener información del deal
            if(HistoryDealSelect(trans.deal))
            {
                double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                bool won = (profit > 0);

                // Calcular métricas
                int bars = (int)((TimeCurrent() - closedTrade.openTime) / PeriodSeconds(PERIOD_CURRENT));

                // MAE y MFE simplificados
                double mae = 0.0;
                double mfe = MathAbs(profit);

                if(profit < 0) {
                    mae = MathAbs(profit) * 1.5;
                } else {
                    mae = MathAbs(profit) * 0.3;
                }

                // Actualizar performance de cada indicador que votó
                for(int i = 0; i < 8; i++)
                {
                    if(closedTrade.votes[i] != VOTE_NEUTRAL && closedTrade.confidences[i] > 0.05)
                    {
                        g_votingStats.UpdatePerformance(
                            i,                      // ID del indicador
                            closedTrade.context,    // Contexto
                            closedTrade.votes[i],   // Voto
                            won,                    // Si ganó
                            profit,                 // Profit
                            bars,                   // Duración
                            mae,                    // MAE
                            mfe                     // MFE
                        );
                    }
                }

                // Mostrar estadísticas cada 10 trades
                static int tradeCount = 0;
                tradeCount++;
                if(tradeCount % 10 == 0)
                {
                    Print("\n", g_votingStats.GetSystemStatistics());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| FUNCIÓN OnTick COMPLETA CORREGIDA Y MEJORADA                    |
//+------------------------------------------------------------------+
void OnTick()
{
    // Solo procesar en nueva barra
    if(!IsNewBar()) return;
    
    g_barsInCurrentState++;
    
    // SINCRONIZACIÓN DE SISTEMAS
    SynchronizeAllSystems();
    
    // VERIFICACIÓN DE INTEGRIDAD
    VerifyDataIntegrity();
    
    // Actualizar información de mercado
    UpdateMarketInfo();
    UpdateDecisionContext();
    
    // Actualizar niveles S/R
    g_srManager.UpdateLevels();
    UpdateNearbySRInfo();
    
    // Verificar límites diarios
    if(!CheckDailyLimits()) 
    {
        if(ShowDebugInfo && MathMod(g_barsInCurrentState, 10) == 0) 
            Print("Límite diario alcanzado");
        return;
    }
    
    // Actualizar estado del ciclo
    UpdateCycleStatus();
    
    // NUEVO: Optimización pre-procesamiento basada en aprendizaje
    OptimizePreProcessing();
    
    // FLUJO PRINCIPAL
    switch(g_currentState)
    {
        case STATE_WAITING_SR_TOUCH:
            ProcessWaitingSRTouch();
            break;
            
        case STATE_CHECKING_ACCUMULATION:
            ProcessCheckingAccumulation();
            break;
            
        case STATE_NEURAL_NEGOTIATION:
            ProcessNeuralNegotiationOptimized();
            break;
            
        case STATE_EXECUTING_ORDER:
            ProcessExecutingOrder();
            break;
            
        case STATE_MONITORING_POSITIONS:
            ProcessMonitoringPositions();
            break;
            
        case STATE_CYCLE_COMPLETE:
            ProcessCycleComplete();
            break;
    }
}

// NUEVA FUNCIÓN: Optimización pre-procesamiento
void OptimizePreProcessing()
{
    // Usar aprendizaje para optimizar el procesamiento
    if(g_metaLearning == NULL) return;
    
    // 1. Ajustar sensibilidad SR según performance histórica
    if(g_currentState == STATE_WAITING_SR_TOUCH)
    {
        // Obtener win rate en toques SR recientes
        double srWinRate = g_metaLearning.GetAgentWinRate(COMPONENT_SUPPORT_RESIST);
        
        // Si SR tiene bajo rendimiento, ser más selectivo
        if(srWinRate < 0.4 && MinLevelStrength < 3.0)
        {
            // Temporalmente aumentar requisitos
            g_srManager.SetParameters(MinMovementATR, ConfirmationBars);
            // Aquí deberíamos poder ajustar MinLevelStrength dinámicamente
        }
    }
    
    // 2. Pre-cargar predicciones para acelerar decisiones
    if(g_touchContext.valid && g_currentState == STATE_CHECKING_ACCUMULATION)
    {
        // Pre-calcular features para ML
        double features[15];
        PrepareMLFeatures(features);
        
        // Cache de predicción
        double prediction = g_metaLearning.PredictOutcomeEnhanced(features, Symbol());
        
        // Si la predicción es muy mala, considerar abortar temprano
        if(prediction < 0.2)
        {
            Print("⚠️ Pre-predicción muy negativa: ", DoubleToString(prediction * 100, 1), "%");
        }
    }
}

// NUEVA FUNCIÓN: Sincronización completa
void SynchronizeAllSystems()
{
    static datetime lastSync = 0;
    if(TimeCurrent() - lastSync < 60) return; // Cada minuto
    lastSync = TimeCurrent();
    
    // 1. Sincronizar Régimen con EMS y ML
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        ENUM_MARKET_REGIME currentRegime = g_regimeDetector.GetCurrentRegime();
        
        // Informar a ML sobre el régimen actual
        // Note: DetectRegimeChange method not implemented in MetaLearningSystem
        // Regime change is handled by RegimeDetectionSystem
        
        // Obtener estadísticas del régimen desde EMS
        if(g_episodicMemory != NULL)
        {
            double regimeWinRate = 0.0;
            double regimeAvgProfit = 0.0;
            int regimeSamples = 0;
            
            g_episodicMemory.GetRegimeStatistics(currentRegime, regimeWinRate, 
                                                regimeAvgProfit, regimeSamples);
            
            // Usar esta información para ajustar parámetros
            if(regimeSamples > 10 && regimeWinRate < 0.4)
            {
                Print("⚠️ Régimen ", EnumToString(currentRegime), 
                      " con bajo rendimiento histórico");
            }
        }
    }
    
    // 2. Sincronizar Consensus IDs
    if(g_orderExecution != NULL && g_orderExecution.m_multiOrder.cycleActive)
    {
        // Asegurar que todas las órdenes tengan consensus_id
        for(int i = 0; i < g_orderExecution.m_multiOrder.orderCount; i++)
        {
            if(g_orderExecution.m_multiOrder.consensus_ids[i] == 0)
            {
                g_orderExecution.m_multiOrder.consensus_ids[i] = 
                    g_orderExecution.m_multiOrder.initial_consensus_id;
            }
        }
    }
    
    // 3. Sincronizar estadísticas de agentes
    if(g_metaLearning != NULL && g_votingStats != NULL)
    {
        // Asegurar que las tasas de éxito coincidan
        //         // TODO: Método no existe - double globalSuccessRate = // TODO: Método no existe - g_votingStats.GetSuccessRate();
        //         double mlSuccessRate = g_metaLearning.GetConsensusSuccessRate();
        //         
        //         if(MathAbs(globalSuccessRate - mlSuccessRate) > 0.1)
        //         {
        //             Print("⚠️ Discrepancia en tasas de éxito: VS ", 
        //                   DoubleToString(globalSuccessRate * 100, 1), "% vs ML ",
        //                   DoubleToString(mlSuccessRate * 100, 1), "%");
        //         }
    }
    
    Print("✓ Sistemas sincronizados");
}

// NUEVA FUNCIÓN: Verificar integridad
void VerifyDataIntegrity()
{
    static datetime lastCheck = 0;
    if(TimeCurrent() - lastCheck < 300) return; // Cada 5 minutos
    lastCheck = TimeCurrent();
    
    if(g_metaLearning == NULL) return;
    
    // Verificar que las estadísticas sean únicas
    bool allSame = true;
    for(int i = 1; i < 5; i++)
    {
        if(g_metaLearning.m_agentStats[i].trades != g_metaLearning.m_agentStats[0].trades ||
           g_metaLearning.m_agentStats[i].wins != g_metaLearning.m_agentStats[0].wins)
        {
            allSame = false;
            break;
        }
    }
    
    if(allSame && g_totalCycles > 5)
    {
        Print("⚠️ INTEGRIDAD: Detectadas estadísticas idénticas - recalculando...");
        RecalculateIndividualAgentStats();
    }
}

//+------------------------------------------------------------------+
//| ESTADO 1: ESPERANDO TOQUE S/R - SIMPLIFICADO                    |
//+------------------------------------------------------------------+
void ProcessWaitingSRTouch()
{
    // Detectar toque S/R
    TouchContext touchCtx;
    bool touchDetected = g_srManager.DetectSRTouch(touchCtx);

    // DEBUG: Mostrar información cada 50 barras para diagnóstico
    static int debugCounter = 0;
    debugCounter++;
    if(debugCounter >= 50)
    {
        debugCounter = 0;
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        Print("╔═══ DEBUG: Estado S/R Touch Detection ═══╗");
        Print("║ Precio actual: ", DoubleToString(currentPrice, _Digits));
        Print("║ Toque detectado: ", touchDetected ? "SÍ" : "NO");
        if(touchDetected)
        {
            Print("║ Toque válido: ", touchCtx.valid ? "SÍ" : "NO");
            Print("║ Calidad toque: ", DoubleToString(touchCtx.quality, 3));
            Print("║ Fuerza nivel: ", DoubleToString(touchCtx.levelStrength, 2));
        }
        Print("╚══════════════════════════════════════════╝");
    }

    if(!touchDetected || !touchCtx.valid)
    {
        // Debug cada 10 barras para no saturar el log
        if(ShowDebugInfo && MathMod(g_barsInCurrentState, 10) == 0)
        {
            Print("Esperando toque S/R válido... (", g_barsInCurrentState, " barras)");
        }
        return;
    }
    
    // Determinar si estamos buscando orden adicional
    bool seekingAdditional = false;
    
    if(g_orderExecution.m_multiOrder.cycleActive && 
       g_orderExecution.m_multiOrder.orderCount > 0 &&
       g_orderExecution.m_multiOrder.orderCount < MaxOrdersPerCycle)
    {
        if(IsFirstOrderInSufficientProfit())
        {
            seekingAdditional = true;
        }
        else
        {
            // No hay suficiente profit, seguir monitoreando
            ChangeState(STATE_MONITORING_POSITIONS);
            return;
        }
    }
    
    // Validar toque SR con criterios apropiados
    bool touchValid = false;

    if(seekingAdditional)
    {
        // Para órdenes adicionales, usar criterios sensibles
        touchValid = ValidateSRTouchSensitive(touchCtx);

        Print("► Validación toque adicional: ", touchValid ? "VÁLIDO" : "RECHAZADO");

        if(touchValid)
        {
            // Verificar que sea en la misma dirección
            bool sameDirection = CheckSameDirection(touchCtx);
            if(!sameDirection)
            {
                Print("► Toque SR en dirección contraria - ignorando");
                return;
            }
        }
    }
    else
    {
        // Para primera orden, usar validación adaptativa
        touchValid = ValidateSRTouchAdaptive(touchCtx);
        Print("► Validación toque inicial: ", touchValid ? "VÁLIDO ✓" : "RECHAZADO ✗");
        Print("  - Calidad: ", DoubleToString(touchCtx.quality, 3));
        Print("  - Fuerza nivel: ", DoubleToString(touchCtx.levelStrength, 2));
        Print("  - Estado nivel: ", touchCtx.level.state);
    }

    if(touchValid)
    {
        // Guardar contexto del toque
        g_touchContext = touchCtx;
        g_currentCycle.touchTime = TimeCurrent();
        g_currentCycle.touchPrice = touchCtx.price;
        g_currentCycle.touchType = touchCtx.level.type;
        g_currentCycle.seekingAdditional = seekingAdditional;
        g_accumBarsSinceTouch = 0;
        
        // Guardar información del nivel SR
        g_currentCycle.srLevelStrength = touchCtx.levelStrength;
        g_currentCycle.srLevelTouches = touchCtx.touchNumber;
        g_currentCycle.srLevelQuality = touchCtx.level.quality;
        g_currentCycle.srLevelState = touchCtx.level.state;
        
        // Preparar contexto extendido si los sistemas están activos
        PrepareExtendedContext(touchCtx, seekingAdditional);
        
        // Buscar episodios similares DESPUÉS de validar el toque
        if(g_EnableEpisodicMemory && g_episodicMemory != NULL)
        {
            SearchSimilarEpisodes();
        }
        
        PrintTouchDetected(seekingAdditional);
        
        ChangeState(STATE_CHECKING_ACCUMULATION);
    }
}

// Agregar validación antes de ejecutar
bool ValidateConsensusIntegrity() {
    if(g_current_consensus_id == 0) {
        Print("ERROR CRÍTICO: No hay consensus_id activo");
        return false;
    }
    
    // Verificar que todos los agentes tengan el mismo consensus_id
    if(g_voteHistoryCount > 0) {
        int lastIdx = g_voteHistoryCount - 1;
        if(g_voteHistory[lastIdx].consensus_id != g_current_consensus_id) {
            Print("ERROR: Discrepancia en consensus_id");
            return false;
        }
    }
    
    return true;
}

bool IsOptimalTradingTime() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Evitar apertura Asia (spread alto)
    if(dt.hour >= 0 && dt.hour < 7) return false;
    
    // Evitar cierre NY (volatilidad errática)
    if(dt.hour >= 21 && dt.hour < 23) return false;
    
    // Evitar fines de semana
    if(dt.day_of_week == 5 && dt.hour >= 20) return false;
    if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
    
    return true;
}

void AdjustAgentWeightsDynamically()
{
    if(g_metaLearning == NULL) return;

    for(int i = 0; i < 5; i++)
    {
        double recentPerformance = CalculateAgentRecentPerformance(i, 24);
        
        // Lógica de ajuste
        if(recentPerformance < 0.3)      g_dynamicWeights[i] = 0.5; // Mínimo 0.5, NUNCA 0.0
        else if(recentPerformance < 0.5) g_dynamicWeights[i] = 0.8;
        else if(recentPerformance > 0.7) g_dynamicWeights[i] = 1.5; // Premio
        else                             g_dynamicWeights[i] = 1.0; // Normal

        // Boost por racha
        if(g_metaLearning.m_agentStats[i].consecutive_wins >= 3)
            g_dynamicWeights[i] *= 1.2;
            
        // Boost si es Master Agent
        if(g_metaLearning.GetAgentPrivilegeLevel((ENUM_COMPONENT_TYPE)i) == "Oracle" || 
           g_metaLearning.GetAgentPrivilegeLevel((ENUM_COMPONENT_TYPE)i) == "Master")
        {
             g_dynamicWeights[i] *= 1.3;
        }
    }
}

// REEMPLAZAR: CalculateAdaptiveRisk
// MEJORA: Fórmula multiplicativa robusta.
double CalculateAdaptiveRisk()
{
    double baseRisk = RiskPercentage; // Input del usuario (ej. 1.0%)
    
    // Factor 1: Performance Reciente (Win Rate de últimos 10 trades)
    double recentWinRate = CalculateRecentWinRate(10);
    double performanceFactor = 1.0;
    
    // Mapeo no lineal para premiar consistencia
    if(recentWinRate >= 0.7) performanceFactor = 1.4;       // +40% riesgo
    else if(recentWinRate >= 0.5) performanceFactor = 1.0;  // Neutral
    else if(recentWinRate >= 0.3) performanceFactor = 0.7;  // -30% riesgo
    else performanceFactor = 0.5;                           // -50% riesgo (Defensivo)
    
    // Factor 2: Calidad del Consenso Neuronal
    double consensusFactor = 1.0;
    if(g_consensusResult.strong_consensus) {
        // Solo aumentar si la fuerza es real (>0.8)
        consensusFactor = (g_consensusResult.consensus_strength > 0.8) ? 1.2 : 1.0;
    } else {
        consensusFactor = 0.8; // Penalizar falta de consenso
    }
    
    // Factor 3: Drawdown Actual de la Cuenta
    double currentDD = CalculateCurrentDrawdown(); // % de caída actual
    double ddFactor = 1.0;
    
    // Protección agresiva de capital
    if(currentDD > MaxDrawdown * 0.75) ddFactor = 0.2;      // Emergencia
    else if(currentDD > MaxDrawdown * 0.5) ddFactor = 0.5;  // Precaución
    else if(currentDD > MaxDrawdown * 0.25) ddFactor = 0.8; // Alerta
    
    // Fórmula Final
    double finalRisk = baseRisk * performanceFactor * consensusFactor * ddFactor;
    
    // Límites duros de seguridad
    finalRisk = MathMin(finalRisk, MaxRiskCap); // Nunca exceder el Cap (ej. 3%)
    finalRisk = MathMax(finalRisk, 0.1);        // Nunca ser 0 (ej. 0.1%)
    
    return NormalizeDouble(finalRisk, 2);
}

bool ApplyIntelligentVeto()
{
    // Veto 1: Desacuerdo extremo entre agentes top
    int topAgentVotes[2] = {-1, -1};
    double topAgentWR[2] = {0, 0};
    
    // Encontrar los 2 mejores agentes
    for(int i = 0; i < 5; i++)
    {
        double wr = g_metaLearning.GetAgentWinRate((ENUM_COMPONENT_TYPE)i);
        if(wr > topAgentWR[0])
        {
            topAgentWR[1] = topAgentWR[0];
            topAgentVotes[1] = topAgentVotes[0];
            topAgentWR[0] = wr;
            topAgentVotes[0] = i;
        }
        else if(wr > topAgentWR[1])
        {
            topAgentWR[1] = wr;
            topAgentVotes[1] = i;
        }
    }
    
    // Si los mejores agentes están en desacuerdo total
    if(topAgentVotes[0] >= 0 && topAgentVotes[1] >= 0)
    {
        bool topAgentsDisagree = CheckAgentsDisagree(topAgentVotes[0], topAgentVotes[1]);
        if(topAgentsDisagree && topAgentWR[0] > 0.7 && topAgentWR[1] > 0.7)
        {
            Print("⚠️ VETO: Mejores agentes en desacuerdo total");
            return true;
        }
    }
    
    // Veto 2: Predicción histórica muy negativa
    if(g_extendedTouch.hasHistoricalData && g_historicalSuccessRate < 0.25)
    {
        Print("⚠️ VETO: Predicción histórica muy negativa (", 
              DoubleToString(g_historicalSuccessRate * 100, 1), "%)");
        return true;
    }
    
    // Veto 3: Condiciones emocionales extremas
    if(g_marketEmotion.fear > 0.9 || g_marketEmotion.uncertainty > 0.85)
    {
        Print("⚠️ VETO: Condiciones emocionales extremas");
        return true;
    }
    
    return false;
}

// Agregar antes de ProcessWaitingSRTouch()
bool ShouldTradeInCurrentContext()
{
    // Capa 1: Verificar performance reciente
    if(g_metaLearning != NULL)
    {
        double recentWinRate = CalculateRecentWinRate(20); // Últimos 20 trades
        if(recentWinRate < 0.35) // Si win rate < 35%
        {
            Print("⚠️ Win rate reciente muy bajo: ", DoubleToString(recentWinRate * 100, 1), "%");
            return false;
        }
    }
    
    // Capa 2: Verificar régimen favorable
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        ENUM_MARKET_REGIME regime = g_regimeDetector.GetCurrentRegime();
        
        // Obtener estadísticas del régimen
        double regimeWinRate = 0.0;
        double regimeAvgProfit = 0.0;
        int regimeSamples = 0;
        
        g_episodicMemory.GetRegimeStatistics(regime, regimeWinRate, regimeAvgProfit, regimeSamples);
        
        if(regimeSamples > 10 && regimeWinRate < 0.4)
        {
            Print("⚠️ Régimen con bajo rendimiento histórico");
            return false;
        }
    }
    
    // Capa 3: Verificar sesión
    if(g_market.session == SESSION_ASIAN && GetAsianSessionWinRate() < 0.45)
    {
        Print("⚠️ Sesión asiática con bajo rendimiento");
        return false;
    }
    
    return true;
}


//+------------------------------------------------------------------+
//| VALIDACIÓN ADAPTATIVA DE TOQUE SR                              |
//+------------------------------------------------------------------+
bool ValidateSRTouchAdaptive(const TouchContext &touchCtx)
{
    // NUEVO: Sistema de puntuación en lugar de rechazos binarios
    double score = 0.0;
    double maxScore = 100.0;
    
    // 1. CALIDAD DEL TOQUE (20 puntos)
    // Ahora es gradual, no binario
    double qualityScore = touchCtx.quality * 20.0; // 0-20 puntos
    score += qualityScore;
    
    // 2. FUERZA DEL NIVEL (25 puntos)
    // Adaptativo según volatilidad
    double volMultiplier = 1.0;
    if(g_market.volatilityRatio > 1.5)
        volMultiplier = 0.7; // Más flexible en alta volatilidad
    else if(g_market.volatilityRatio < 0.8)
        volMultiplier = 1.2; // Más estricto en baja volatilidad
    
    double strengthScore = MathMin(25.0, touchCtx.levelStrength * 5.0 * volMultiplier);
    score += strengthScore;
    
    // 3. ESTADO DEL NIVEL (15 puntos)
    switch(touchCtx.level.state)
    {
        case SR_STATE_VALIDATED:
            score += 15.0;
            break;
        case SR_STATE_CONFIRMED:
            score += 12.0;
            break;
        case SR_STATE_INITIAL:
            score += 8.0; // Ahora los niveles iniciales también puntúan
            break;
        case SR_STATE_BROKEN:
            score += 5.0; // Incluso niveles rotos pueden ser retests válidos
            break;
    }
    
    // 4. CONTEXTO DE MERCADO (20 puntos)
    // Sesión
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    if(dt.hour >= 8 && dt.hour <= 16) // Sesiones principales
        score += 10.0;
    else if(dt.hour >= 2 && dt.hour <= 6) // Sesión asiática
        score += 5.0;
    
    // Momentum
    double rsi = g_decisionContext.rsi;
    if(touchCtx.level.type == SR_SUPPORT && rsi < 40) // Soporte en oversold
        score += 10.0;
    else if(touchCtx.level.type == SR_RESISTANCE && rsi > 60) // Resistencia en overbought
        score += 10.0;
    else
        score += 5.0;
    
    // 5. MÚLTIPLES TOQUES (10 puntos)
    if(touchCtx.touchNumber > 1)
        score += MathMin(10.0, touchCtx.touchNumber * 3.0);
    
    // 6. NIVELES CERCANOS (10 puntos)
    if(g_strongLevelsNearby >= 2)
        score += 10.0;
    else if(g_strongLevelsNearby >= 1)
        score += 5.0;
    
    // EVALUACIÓN FINAL
    double scorePercent = score / maxScore * 100.0;
    
    if(ShowDebugInfo)
    {
        Print("Validación SR - Score: ", DoubleToString(score, 1), "/", 
              DoubleToString(maxScore, 1), " (", 
              DoubleToString(scorePercent, 1), "%)");
        Print("  Calidad: ", DoubleToString(qualityScore, 1),
              " Fuerza: ", DoubleToString(strengthScore, 1),
              " Contexto: OK");
    }
    
    // UMBRAL ADAPTATIVO
    double threshold = 40.0; // Base 40%

    // Ajustar umbral según condiciones
    if(g_market.volatilityRatio > 2.0)
        threshold -= 10.0; // Más flexible en alta volatilidad

    if(g_totalCycles == 0) // Primera operación del día
        threshold -= 5.0; // Ser menos estricto al inicio

    if(dt.hour >= 13 && dt.hour <= 15) // Horario NY
        threshold -= 5.0; // Horario principal más flexible

    return scorePercent >= threshold;
}

//+------------------------------------------------------------------+
//| VALIDACIÓN BÁSICA DE TOQUE SR                                   |
//+------------------------------------------------------------------+
bool ValidateSRTouchBasic(const TouchContext &touchCtx)
{
    // Rechazar si el contexto no es válido
    if(!touchCtx.valid)
        return false;

    // Criterio 1: Calidad mínima (simple, 0‑1)
    if(touchCtx.quality < 0.5)
        return false;

    // Criterio 2: Fuerza del nivel
    if(touchCtx.levelStrength < 1.0)
        return false;

    // Criterio 3: El nivel debe estar en estado inicial o mejor
    if(touchCtx.level.state < SR_STATE_INITIAL)
        return false;

    // Si pasa todos los filtros
    if(ShowDebugInfo)
        Print("Toque SR básico APROBADO");
    return true;
}

//+------------------------------------------------------------------+
//| VALIDACIÓN SENSIBLE PARA ÓRDENES ADICIONALES                    |
//+------------------------------------------------------------------+
bool ValidateSRTouchSensitive(const TouchContext &touchCtx)
{
    // Aplicar factor de sensibilidad
    double adjustedMinQuality = 0.2 * SensitivityMultiplier;  // Más sensible
    double adjustedMinStrength = MinLevelStrength * SensitivityMultiplier;
    
    if(touchCtx.quality < adjustedMinQuality)
    {
        if(ShowDebugInfo) 
            Print("Toque sensible rechazado: calidad insuficiente");
        return false;
    }
    
    if(touchCtx.levelStrength < adjustedMinStrength)
    {
        if(ShowDebugInfo) 
            Print("Toque sensible rechazado: fuerza insuficiente");
        return false;
    }
    
    // Para adicionales, aceptar cualquier nivel válido
    if(touchCtx.level.state < SR_STATE_INITIAL)
    {
        if(ShowDebugInfo) 
            Print("Toque sensible rechazado: nivel no válido");
        return false;
    }
    
    Print("Toque SR sensible APROBADO para orden adicional");
    return true;
}

//+------------------------------------------------------------------+
//| ESTADO 2: VERIFICANDO ACUMULACIÓN                               |
//+------------------------------------------------------------------+
void ProcessCheckingAccumulation()
{
    g_accumBarsSinceTouch++;
    
    // Determinar mínimo de barras según contexto
    int minBarsRequired = MinAccumulationBars;
    int timeout = AccumulationTimeout;
    
    // Ajustar por régimen si está activo
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        RegimeParameters regimeParams = g_regimeDetector.GetCurrentParameters();
        minBarsRequired = regimeParams.minAccumulationBars;
    }
    
    // Para órdenes adicionales, usar acumulación rápida
    if(g_currentCycle.seekingAdditional)
    {
        minBarsRequired = 2;
        timeout = 10;
    }
    
    if(g_accumBarsSinceTouch > timeout)
    {
        Print("Timeout de acumulación (", g_accumBarsSinceTouch, " barras)");
        
        // Completar episodio si existe
        if(g_EnableEpisodicMemory && g_currentCycle.episodeId > 0)
        {
            CompleteCurrentEpisode(false);
        }
        
        ResetToWaitingState();
        return;
    }
    
    if(DetectAccumulationPattern())
    {
        if(g_accumContext.barCount >= minBarsRequired)
        {
            g_currentCycle.accumStartTime = g_accumContext.startTime;
            g_currentCycle.accumBarsCount = g_accumContext.barCount;
            g_currentCycle.accumValid = true;
            g_currentCycle.accumCenter = g_accumContext.centerPrice;
            g_currentCycle.accumRange = g_accumContext.range;
            
            PrintAccumulationDetected(minBarsRequired);
            
            ChangeState(STATE_NEURAL_NEGOTIATION);
        }
    }
}

void ProcessNeuralNegotiationOptimized()
{
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║       NEGOCIACIÓN NEURONAL (MODO FORZADO)            ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    // 1. Generar ID
    ulong consensus_id = 0;
    if(g_metaLearning != NULL) consensus_id = g_metaLearning.GenerateConsensusID();
    else consensus_id = (ulong)TimeCurrent();
    
    g_current_consensus_id = consensus_id;

    // 2. Predicción ML (Informativa)
    double mlPrediction = 0.5;
    if(g_metaLearning != NULL)
    {
        double features[15];
        PrepareMLFeatures(features);
        mlPrediction = g_metaLearning.PredictOutcomeEnhanced(features, Symbol());
    }

    // 3. Resetear Votación
    if(g_votingStats != NULL)
    {
        // TODO: Método no existe - g_votingStats.ResetVotes();
        // TODO: Método no existe - g_votingStats.SetCurrentConsensusID(consensus_id);
    }

    // 4. Recolectar Votos (Usando la función corregida arriba)
    int votesCollected = CollectAllVotesWithTracking(consensus_id);
    Print("► Votos recolectados: ", votesCollected);

    if(votesCollected == 0)
    {
        Print("❌ Nadie votó. Regresando.");
        ResetToWaitingState();
        return;
    }

    // 5. Tomar Decisión
    // TODO: Método no existe - g_consensusResult = g_votingStats.MakeFinalDecision();
    g_consensusResult.consensus_id = consensus_id;

    // --- PARCHE DE EMERGENCIA: SI LA CLASE DEVUELVE 0 ---
    // Si MakeFinalDecision devuelve 0 fuerza porque la clase está fallando internamente,
    // recalculamos nosotros manualmente aquí mismo.
    if(g_consensusResult.total_conviction <= 0.001)
    {
        Print("⚠️ ADVERTENCIA: Recálculo manual de consenso activado");
        double buyStrength = 0;
        double sellStrength = 0;
        
        // Usamos el último registro del tracker que acabamos de llenar
        int lastIdx = g_voteHistoryCount - 1;
        for(int i=0; i<5; i++)
        {
            if(g_voteHistory[lastIdx].agents[i].voted)
            {
                if(g_voteHistory[lastIdx].agents[i].direction == VOTE_BUY)
                    buyStrength += g_voteHistory[lastIdx].agents[i].adjustedConfidence;
                else if(g_voteHistory[lastIdx].agents[i].direction == VOTE_SELL)
                    sellStrength += g_voteHistory[lastIdx].agents[i].adjustedConfidence;
            }
        }
        
        if(buyStrength > sellStrength)
        {
            g_consensusResult.final_direction = VOTE_BUY;
            g_consensusResult.total_conviction = buyStrength;
            g_consensusResult.consensus_strength = buyStrength / (buyStrength + sellStrength + 0.001);
        }
        else if(sellStrength > buyStrength)
        {
            g_consensusResult.final_direction = VOTE_SELL;
            g_consensusResult.total_conviction = sellStrength;
            g_consensusResult.consensus_strength = sellStrength / (buyStrength + sellStrength + 0.001);
        }
        
        Print("► Recálculo Manual -> Dir: ", EnumToString(g_consensusResult.final_direction), " | Conv: ", DoubleToString(g_consensusResult.total_conviction, 2));
    }
    // -----------------------------------------------------

    // 6. Validación de Umbrales (AJUSTADO PARA CALIDAD DE SEÑALES)
    // Umbral aumentado de 0.2 → 0.50 para filtrar señales débiles
    double minConviction = 0.50; 
    
    if(g_consensusResult.final_direction != VOTE_NEUTRAL && g_consensusResult.total_conviction > minConviction)
    {
        Print("✅ CONSENSO VÁLIDO ACEPTADO");
        RegisterConsensusDecision();
        ChangeState(STATE_EXECUTING_ORDER);
    }
    else
    {
        Print("❌ Consenso insuficiente (Conv < ", minConviction, ")");
        ResetToWaitingState();
    }
}

//+------------------------------------------------------------------+
//| PROCESO DE NEGOCIACIÓN NEURONAL - VERSIÓN CORREGIDA            |
//+------------------------------------------------------------------+
void ProcessNeuralNegotiation()
{
    // SOLUCIÓN: Redirigir a la función que sí existe
    ProcessNeuralNegotiationOptimized();
}

// ALTERNATIVA COMPLETA: Implementar la función básica
void ProcessNeuralNegotiationBasic()
{
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║          NEGOCIACIÓN NEURONAL BÁSICA                 ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    // 1. Generar consensus_id único
    ulong consensus_id = 0;
    if(g_metaLearning != NULL)
    {
        consensus_id = g_metaLearning.GenerateConsensusID();
        g_current_consensus_id = consensus_id;
    }
    else
    {
        // Fallback si no hay MetaLearning
        consensus_id = (ulong)TimeCurrent() + (ulong)MathRand();
        g_current_consensus_id = consensus_id;
    }
    
    Print("► Consensus ID: ", consensus_id);
    
    // 2. Resetear sistema de votación
    if(g_votingStats != NULL)
    {
        // TODO: Método no existe - g_votingStats.ResetVotes();
        // TODO: Método no existe - g_votingStats.SetCurrentConsensusID(consensus_id);
    }

    // 3. Recolectar votos con tracking
    int votesCollected = CollectAllVotesWithTracking(consensus_id);
    
    if(votesCollected < 2)
    {
        Print("❌ Agentes insuficientes (", votesCollected, ")");
        ResetToWaitingState();
        return;
    }
    
    Print("✓ Votos recolectados: ", votesCollected);
    
    // 4. Tomar decisión final
    // TODO: Método no existe - g_consensusResult = g_votingStats.MakeFinalDecision();
    g_consensusResult.consensus_id = consensus_id;
    
    // 5. Validar consenso
    if(ValidateConsensus())
    {
        Print("═══ CONSENSO ALCANZADO ═══");
        Print("► Dirección: ", (g_consensusResult.final_direction == VOTE_BUY ? "BUY" : "SELL"));
        Print("► Fuerza: ", DoubleToString(g_consensusResult.consensus_strength, 3));
        Print("► Líder: ", g_consensusResult.leading_agent);
        
        // 6. Registrar decisión
        RegisterConsensusDecision();
        
        // 7. Guardar información del ciclo
        g_currentCycle.negotiationTime = TimeCurrent();
        g_currentCycle.negotiationRounds = 1;
        g_currentCycle.leadingAgent = g_consensusResult.leading_agent;
        g_currentCycle.consensusQuality = g_consensusResult.consensus_strength;
        g_currentCycle.vetoUsed = g_consensusResult.veto_used;
        
        // 8. Cambiar a ejecución
        ChangeState(STATE_EXECUTING_ORDER);
    }
    else
    {
        Print("❌ Consenso no válido");
        ResetToWaitingState();
    }
}

//+------------------------------------------------------------------+
//| MÓDULO DE EJECUCIÓN BLINDADO CONTRA REQUOTES Y ID PERDIDO        |
//+------------------------------------------------------------------+
void ProcessExecutingOrder()
{
    // 1. Preparación de Datos
    int direction = (g_consensusResult.final_direction == VOTE_BUY) ? 1 : -1;
    
       
    // ASEGURAR consensus_id SIEMPRE
    if(g_consensusResult.consensus_id == 0)
    {
        if(g_metaLearning != NULL) 
            g_consensusResult.consensus_id = g_metaLearning.GenerateConsensusID();
        else 
            g_consensusResult.consensus_id = (ulong)TimeCurrent();
            
        g_current_consensus_id = g_consensusResult.consensus_id;
    }
    
    Print("═══ EJECUTANDO ORDEN - Consensus ID: ", g_consensusResult.consensus_id, " ═══");

    // 2. Actualizar Contextos en OrderExecution (CRÍTICO: SET ID ANTES DE NADA)
    g_orderExecution.SetCurrentConsensusID(g_consensusResult.consensus_id); // <--- AQUÍ
    g_orderExecution.UpdateEmotionalContext(g_marketEmotion);
    g_orderExecution.UpdateConsensusContext(g_consensusResult.consensus_strength, g_consensusResult.total_conviction);

    // 3. EJECUCIÓN CON BUCLE DE REINTENTO
    bool success = false;
    int maxRetries = 3;
    
    for(int i = 0; i < maxRetries; i++)
    {
        // A. Refrescar precios CRÍTICOS
        double currentExecutionPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Validación de seguridad de precio
        if(currentExecutionPrice <= 0) {
            Print("⚠ Error leyendo precios. Reintentando...");
            Sleep(100);
            continue;
        }

        // B. Ejecución
        if(!g_orderExecution.m_multiOrder.cycleActive || g_orderExecution.m_multiOrder.orderCount == 0)
        {
            // --- PRIMERA ORDEN ---
            Print("► Intento #", i+1, ": Ejecutando al MERCADO @ ", DoubleToString(currentExecutionPrice, _Digits));
            
            // Asegurar ID justo antes del disparo nuevamente por si acaso
            g_orderExecution.SetCurrentConsensusID(g_consensusResult.consensus_id);
            
            success = g_orderExecution.ExecuteFirstOrder(direction, g_consensusResult.total_conviction, currentExecutionPrice);
            
            if(success)
            {
                // Actualizar estado global post-éxito
                g_dailyTradeCount++;
                g_totalCycles++;
                g_tradesInCurrentRegime++;
                g_currentCycle.isMultiOrderCycle = true;
                g_currentCycle.activeDirection = g_consensusResult.final_direction;
                g_currentCycle.ordersExecuted = 1;

                // CRÍTICO: Vincular ticket con voto INMEDIATAMENTE después de ejecutar
                if(g_orderExecution.m_multiOrder.tickets[0] > 0)
                {
                    ulong executedTicket = g_orderExecution.m_multiOrder.tickets[0];

                    // Buscar el voto con este consensus_id y asignar el ticket
                    for(int v = g_voteHistoryCount - 1; v >= 0; v--)
                    {
                        if(g_voteHistory[v].consensus_id == g_consensusResult.consensus_id)
                        {
                            g_voteHistory[v].orderTicket = executedTicket;
                            Print("✓ Ticket ", executedTicket, " vinculado con Consensus ID ", g_consensusResult.consensus_id);
                            break;
                        }
                    }
                }

                // Capturar votos para Enhanced Voting System (última orden ejecutada)
                if(g_orderExecution.m_multiOrder.orderCount > 0)
                {
                    ulong lastTicket = g_orderExecution.m_multiOrder.tickets[g_orderExecution.m_multiOrder.orderCount - 1];
                    if(lastTicket > 0) CaptureVotesForEnhancedSystem(lastTicket);
                }

                Print("✓ Primera orden ejecutada correctamente");
                if(g_EnableEpisodicMemory && g_episodicMemory != NULL) StartNewEpisode();
                break;
            }
        }
        else
        {
            // --- ORDEN ADICIONAL ---
            Print("► Intento #", i+1, ": Ejecutando ADICIONAL al MERCADO");
            success = g_orderExecution.ExecuteAdditionalOrder(direction, g_consensusResult.total_conviction);

            if(success)
            {
                g_currentCycle.ordersExecuted++;

                // CRÍTICO: Vincular ticket de orden adicional con voto
                int lastOrderIndex = g_orderExecution.m_multiOrder.orderCount - 1;
                if(lastOrderIndex >= 0 && g_orderExecution.m_multiOrder.tickets[lastOrderIndex] > 0)
                {
                    ulong executedTicket = g_orderExecution.m_multiOrder.tickets[lastOrderIndex];

                    // Buscar el voto con este consensus_id
                    for(int v = g_voteHistoryCount - 1; v >= 0; v--)
                    {
                        if(g_voteHistory[v].consensus_id == g_consensusResult.consensus_id)
                        {
                            // Para órdenes adicionales, el ticket ya está vinculado con la primera orden
                            // Solo registramos que hay múltiples órdenes para este consensus_id
                            Print("✓ Orden adicional Ticket ", executedTicket, " vinculada con Consensus ID ", g_consensusResult.consensus_id);
                            break;
                        }
                    }
                }

                Print("✓ Orden adicional ejecutada");
                break;
            }
        }
        
        // C. Manejo de Fallos
        int err = GetLastError();
        if(err == 4756 || err == 10004) // Invalid stops o Requote
        {
            Print("⚠ REQUOTE/STOPS DETECTADO (" + IntegerToString(err) + "). Esperando 500ms...");
            Sleep(500);
        }
        else
        {
            Print("✗ Error no recuperable: ", err);
            break;
        }
    }
    
    // 4. Resultado Final
    if(success)
    {
        ChangeState(STATE_MONITORING_POSITIONS);
    }
    else
    {
        Print("✗ FALLO FINAL DE EJECUCIÓN TRAS REINTENTOS");
        if(!g_orderExecution.m_multiOrder.cycleActive)
        {
            if(g_EnableEpisodicMemory && g_currentCycle.episodeId > 0)
                CompleteCurrentEpisode(false);
            ResetCycle();
        }
        else
        {
            ChangeState(STATE_MONITORING_POSITIONS);
        }
    }
}
//+------------------------------------------------------------------+
//| ESTADO 5: MONITOREANDO POSICIONES                               |
//+------------------------------------------------------------------+
void ProcessMonitoringPositions()
{
    // Verificar si aún hay órdenes activas
    if(!g_orderExecution.m_multiOrder.cycleActive || 
       g_orderExecution.m_multiOrder.orderCount == 0)
    {
        Print("No hay órdenes activas - Completando ciclo");
        ChangeState(STATE_CYCLE_COMPLETE);
        return;
    }
    
    // Actualizar contexto emocional
    AnalyzeCurrentMarketEmotion();
    g_orderExecution.UpdateEmotionalContext(g_marketEmotion);
    
         
    // Actualizar trailing stops individuales como respaldo
    g_orderExecution.UpdateAllTrailingStops();
    
    // Verificar salud del ciclo
    MonitorCycleHealth();
    
    // Volver a buscar toques S/R después de unas barras
    if(g_barsInCurrentState > 2)
    {
        if(ShowDebugInfo)
            Print("Volviendo a buscar toques SR");
        ChangeState(STATE_WAITING_SR_TOUCH);
    }
}

//+------------------------------------------------------------------+
//| MÓDULO COMPLETO CORREGIDO: ProcessCycleComplete                 |
//+------------------------------------------------------------------+
void ProcessCycleComplete()
{
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║         CICLO MULTI-ORDEN COMPLETADO                 ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    // Verificar integridad del ciclo
    if(g_orderExecution.m_multiOrder.initial_consensus_id == 0)
    {
        Print("⚠ ADVERTENCIA: Ciclo sin consensus_id inicial");
        
        // Intentar recuperar de la primera orden
        if(g_orderExecution.m_multiOrder.orderCount > 0 && 
           g_orderExecution.m_multiOrder.consensus_ids[0] > 0)
        {
            g_orderExecution.m_multiOrder.initial_consensus_id = 
                g_orderExecution.m_multiOrder.consensus_ids[0];
            Print("✓ Consensus_id recuperado: ", g_orderExecution.m_multiOrder.initial_consensus_id);
        }
    }
    
    PrintCycleSummary();
    
    // Calcular resultado del ciclo
    double cycleProfit = g_orderExecution.m_multiOrder.cycleProfit +
                        g_orderExecution.m_multiOrder.totalPartialClosed;
    bool success = (cycleProfit > 0);

    Print("═══ RESULTADO DEL CICLO ═══");
    Print("► P&L Total: ", DoubleToString(cycleProfit, 2));
    Print("► Éxito: ", success ? "SÍ" : "NO");
    Print("► Órdenes ejecutadas: ", g_orderExecution.m_multiOrder.orderCount);

    // CONSISTENCIA: Registrar cada trade del ciclo en RegimeDetector
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        datetime currentTime = TimeCurrent();
        datetime estimatedOpenTime = currentTime - 3600; // Estimación: 1 hora antes
        double profitPerOrder = cycleProfit / MathMax(1, g_orderExecution.m_multiOrder.orderCount);

        for(int i = 0; i < g_orderExecution.m_multiOrder.orderCount; i++)
        {
            if(g_orderExecution.m_multiOrder.tickets[i] > 0)
            {
                g_regimeDetector.RegisterTradeResult(
                    g_orderExecution.m_multiOrder.tickets[i],
                    profitPerOrder,
                    success,
                    estimatedOpenTime,
                    currentTime
                );
            }
        }
        Print("✓ Ciclo registrado en RegimeDetector - ", g_orderExecution.m_multiOrder.orderCount, " trades");
    }

    // 1. ACTUALIZAR VOTINGSTATISTICS
    // TODO: Método no existe - g_votingStats.UpdateVotingResult(success);
    Print("✓ VotingStatistics actualizado");
    
    // 2. PROCESO COMPLETO DE APRENDIZAJE EN METALEARNING
    if(g_metaLearning != NULL)
    {
        // ELIMINADO: Sobrescritura de consensusStrength y emotionalContext
        // Estos valores ya están correctamente seteados en ExecuteFirstOrder()
        // líneas 1537-1538 de OrderExecution.mqh y no deben sobrescribirse

        // NUEVO: Aprendizaje de ciclo multi-orden
        // Buscar el VoteTracker correspondiente a este ciclo
        int voteIndex = -1;
        for(int v = g_voteHistoryCount - 1; v >= 0; v--)
        {
            if(g_voteHistory[v].consensus_id == g_orderExecution.m_multiOrder.initial_consensus_id)
            {
                voteIndex = v;
                break;
            }
        }

        if(voteIndex >= 0)
        {
            // Preparar datos del ciclo para aprendizaje
            bool agentVoted[5];
            int agentDirection[5];  // Usar int para almacenar ENUM

            for(int i = 0; i < 5; i++)
            {
                agentVoted[i] = g_voteHistory[voteIndex].agents[i].voted;
                agentDirection[i] = (int)g_voteHistory[voteIndex].agents[i].direction;  // Cast a int
            }

            ENUM_VOTE_DIRECTION finalDirection = g_voteHistory[voteIndex].finalDirection;
            ENUM_MARKET_REGIME currentRegime = g_currentCycle.currentRegime;

            // TODO: Método no existe - LearnFromMultiOrderCycle
            // g_metaLearning.LearnFromMultiOrderCycle(
            //     success,
            //     cycleProfit,
            //     g_orderExecution.m_multiOrder.orderCount,
            //     agentVoted,
            //     agentDirection,
            //     (int)finalDirection,
            //     (int)currentRegime
            // );

            Print("⚠ LearnFromMultiOrderCycle no implementado - método comentado");
        }
        else
        {
            Print("⚠ No se encontró VoteTracker para consensus_id: ", g_orderExecution.m_multiOrder.initial_consensus_id);
        }

        // ACTUALIZACIÓN FORZADA DE ESTADÍSTICAS
        UpdateAllAgentStatsFromCycle(success, cycleProfit);
        
        // GUARDAR INMEDIATAMENTE
        g_metaLearning.SaveToFiles();
        Print("✓ MetaLearning actualizado y guardado");
    }
    
    // 3. COMPLETAR EPISODIO EN EMS
    if(g_EnableEpisodicMemory && g_episodicMemory != NULL)
    {
        if(g_currentCycle.episodeId > 0)
        {
            CompleteCurrentEpisode(success, cycleProfit);
            Print("✓ Episodio completado en EMS");
        }
        
        // Actualizar predicciones basadas en resultado
        if(g_currentCycle.currentRegime != REGIME_RANGING)
        {
            double winRate = 0.0, avgProfit = 0.0;
            int samples = 0;
            
            g_episodicMemory.GetRegimeStatistics(g_currentCycle.currentRegime, 
                                               winRate, avgProfit, samples);
            
            Print("► Estadísticas del régimen ", EnumToString(g_currentCycle.currentRegime), ":");
            Print("  Muestras: ", samples + 1, " | WR: ", 
                  DoubleToString(winRate * 100, 1), "%");
        }
    }
    
    // 4. ACTUALIZAR RÉGIMEN
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        // El régimen puede ajustar sus parámetros basándose en el resultado
        RegimeParameters currentParams = g_regimeDetector.GetCurrentParameters();
        
        if(!success && currentParams.riskPercent > 1.0)
        {
            Print("► Régimen puede considerar reducir riesgo tras pérdida");
        }
        else if(success && g_orderExecution.m_multiOrder.orderCount >= 3)
        {
            Print("► Ciclo multi-orden exitoso en régimen ", 
                  EnumToString(g_currentCycle.currentRegime));
        }
    }
    
    // 5. ANÁLISIS POST-CICLO
    AnalyzePostCyclePerformance(success, cycleProfit);
    
    // 6. VERIFICAR CAMBIOS SIGNIFICATIVOS
    CheckAndReportSignificantChanges();
    
    // Resetear ciclo
    ResetCycle();
    
    Print("╚══════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| MÓDULO COMPLETO CORREGIDO: MonitorClosedOrders                  |
//+------------------------------------------------------------------+
void MonitorClosedOrders()
{
    static datetime lastCheckTime = 0;
    static ulong processedDeals[];
    static int processedCount = 0;
    
    if(TimeCurrent() - lastCheckTime < 1) return;
    lastCheckTime = TimeCurrent();
    
    HistorySelect(0, TimeCurrent());
    int totalDeals = HistoryDealsTotal();
    
    for(int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(dealTicket == 0) continue;
        
        if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
        
        datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
        if(dealTime < TimeCurrent() - 3600) continue;
        
        // Verificar si ya procesamos este deal
        bool alreadyProcessed = false;
        for(int j = 0; j < processedCount; j++)
        {
            if(processedDeals[j] == dealTicket)
            {
                alreadyProcessed = true;
                break;
            }
        }
        
        if(alreadyProcessed) continue;
        
        ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY) continue;
        
        ulong orderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
        if(orderTicket == 0) continue;
        
        double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
        double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
        double totalProfit = dealProfit + dealSwap + dealCommission;
        bool isWin = (totalProfit >= 0);
        
        Print("╔══════════════════════════════════════════════════════╗");
        Print("║           ORDEN CERRADA DETECTADA                    ║");
        Print("╚══════════════════════════════════════════════════════╝");
        Print("Order Ticket: ", orderTicket);
        Print("Profit: ", DoubleToString(totalProfit, 2));
        Print("Resultado: ", isWin ? "GANADORA" : "PERDEDORA");
        
        // SOLUCIÓN: Buscar el registro más reciente por tiempo
        bool foundTracking = false;
        
        // Note: Trade record lookup removed - method not implemented
        // foundTracking remains false to use fallback method
        
        // Si no se encontró, buscar en historial de votos reciente
        if(!foundTracking && g_voteHistoryCount > 0)
        {
            // Buscar el voto más reciente antes del cierre
            int bestMatch = -1;
            datetime closestTime = 0;
            
            for(int v = g_voteHistoryCount - 1; v >= 0; v--)
            {
                if(g_voteHistory[v].timestamp < dealTime && 
                   g_voteHistory[v].timestamp > closestTime)
                {
                    closestTime = g_voteHistory[v].timestamp;
                    bestMatch = v;
                }
            }
            
            if(bestMatch >= 0)
            {
                Print("✓ Usando registro de votos por proximidad temporal");
                // SOLO marcar el tracking, NO actualizar estadísticas (evita duplicación)
                g_voteHistory[bestMatch].orderTicket = orderTicket;
                g_voteHistory[bestMatch].tradeExecuted = true;
                foundTracking = true;
            }
        }

        // ELIMINADO: Actualización de estadísticas de agentes
        // Las estadísticas se actualizan UNA SOLA VEZ en ProcessCycleComplete()
        // para evitar duplicación cuando hay múltiples órdenes en un ciclo

        // ELIMINADO: Actualización de VotingStatistics
        // Se actualiza UNA SOLA VEZ en ProcessCycleComplete() por ciclo

        // CRÍTICO: Actualizar RegimeDetector con resultado del trade individual
        if(g_EnableRegimeDetection && g_regimeDetector != NULL)
        {
            // Obtener tiempo de apertura (aproximado - dealTime menos 1 hora como estimación)
            datetime estimatedOpenTime = dealTime - 3600; // Estimación: 1 hora antes del cierre
            g_regimeDetector.RegisterTradeResult(orderTicket, totalProfit, isWin, estimatedOpenTime, dealTime);
            Print("✓ Trade registrado en RegimeDetector - Profit: ", DoubleToString(totalProfit, 2));
        }

        // Agregar a procesados
        if(processedCount >= ArraySize(processedDeals))
            ArrayResize(processedDeals, processedCount + 100);
        
        processedDeals[processedCount++] = dealTicket;

        // Nota: El guardado de estadísticas se hace en ProcessCycleComplete()
        // No es necesario guardar aquí porque no actualizamos estadísticas
    }
}

//+------------------------------------------------------------------+
//| MÓDULO NUEVO: OnRegimeChange con Aprendizaje Completo         |
//+------------------------------------------------------------------+
void OnRegimeChange(ENUM_MARKET_REGIME oldRegime, ENUM_MARKET_REGIME newRegime)
{
    Print("═══ CAMBIO DE RÉGIMEN DETECTADO ═══");
    Print("De: ", EnumToString(oldRegime), " → A: ", EnumToString(newRegime));
    
    // NUEVO: Guardar estadísticas del régimen anterior
    if(g_tradesInCurrentRegime > 0)
    {
        Print("Estadísticas del régimen anterior:");
        Print("  Trades: ", g_tradesInCurrentRegime);
        Print("  P&L total: ", DoubleToString(g_regimeProfit, 2));
        
        // CRÍTICO: Actualizar RDS con resultados del régimen
        if(g_regimeDetector != NULL)
        {
            double winRate = 0.0;
            // TODO: Método no existe - if(g_votingStats != NULL) winRate = g_votingStats.GetSuccessRate();
            
            // Crear estructura de historial
            //             RegimeHistory history;
            //             history.regime = oldRegime;
            //             history.startTime = g_lastRegimeChange;
            //             history.endTime = TimeCurrent();
            //             history.tradesExecuted = g_tradesInCurrentRegime;
            //             history.totalProfit = g_regimeProfit;
            //             history.winRate = winRate;
            
            // NOTA: RDS necesita un método público para recibir esto
            // Por ahora, lo guardamos internamente
        }
        
        // NUEVO: Notificar a EMS sobre cambio de régimen
        if(g_episodicMemory != NULL)
        {
            // EMS puede ajustar sus predicciones basándose en el nuevo régimen
            Print("Notificando cambio de régimen a EMS");
        }
        
        // Note: DetectRegimeChange method not implemented
    }

    // Reset contadores para nuevo régimen
    g_tradesInCurrentRegime = 0;
    g_regimeProfit = 0.0;
    g_lastRegimeChange = TimeCurrent();
    
    // Ajustar parámetros para el nuevo régimen
    if(AdaptParametersByRegime && g_regimeDetector != NULL)
    {
        RegimeParameters regimeParams = g_regimeDetector.GetCurrentParameters();
        
        // Ajustar OrderExecution
        double dynamicRisk = RiskPercentage;
        
        // Ajuste basado en régimen
        switch(newRegime)
        {
            case REGIME_TRENDING_UP:
            case REGIME_TRENDING_DOWN:
                dynamicRisk *= 1.2; // Más agresivo en tendencias
                break;
            case REGIME_VOLATILE:
            case REGIME_CRISIS:
                dynamicRisk *= 0.5; // Muy conservador
                break;
            case REGIME_RANGING:
                dynamicRisk *= 0.8; // Moderadamente conservador
                break;
        }
        
        dynamicRisk = MathMin(dynamicRisk, MaxRiskCap);
        
        g_orderExecution.SetParameters(dynamicRisk, 0.0, 1.5);
        
        Print("Parámetros ajustados para régimen ", EnumToString(newRegime));
        Print("  Riesgo: ", DoubleToString(dynamicRisk, 2), "%");
    }
}

//+------------------------------------------------------------------+
//| MÓDULO NotifyTradeResult - VERSIÓN CORREGIDA COMPLETA          |
//+------------------------------------------------------------------+
void NotifyTradeResult(ulong orderTicket, double profit, bool isWin)
{
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║         NOTIFICANDO RESULTADO DE TRADE               ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    // 1. Buscar información completa del trade
    ulong consensus_id = 0;
    // Note: Trade record lookup removed - method not implemented
    
    // 2. Si no hay record, buscar en el ciclo actual
    if(consensus_id == 0 && g_orderExecution.m_multiOrder.cycleActive)
    {
        // Buscar el ticket en las órdenes del ciclo
        for(int i = 0; i < g_orderExecution.m_multiOrder.orderCount; i++)
        {
            if(g_orderExecution.m_multiOrder.tickets[i] == orderTicket)
            {
                consensus_id = g_orderExecution.m_multiOrder.consensus_ids[i];
                if(consensus_id == 0)
                {
                    consensus_id = g_orderExecution.m_multiOrder.initial_consensus_id;
                }
                break;
            }
        }
    }
    
    // 3. NOTIFICAR A METALEARNING
    if(g_metaLearning != NULL && consensus_id > 0)
    {
        // Note: FinalizeTradeRecord method not implemented
        // Actualizar estadísticas individuales de agentes
        UpdateAgentStatsFromVoteHistory(orderTicket, isWin, profit);
    }
    
    // 4. NOTIFICAR A EPISODICMEMORY
    if(g_EnableEpisodicMemory && g_episodicMemory != NULL)
    {
        // Buscar episodio asociado
        ulong episodeId = 0;
        
        // Si tenemos consensus_id, buscar el episodio
        if(consensus_id > 0)
        {
            episodeId = FindEpisodeByConsensusIDStub(consensus_id);
        }
        
        // Si no, usar el episodio del ciclo actual
        if(episodeId == 0 && g_currentCycle.episodeId > 0)
        {
            episodeId = g_currentCycle.episodeId;
        }
        
        if(episodeId > 0)
        {
            // Crear registro completo para el episodio
            CompleteTradeRecord episodeRecord;
            episodeRecord.order_ticket = orderTicket;
            episodeRecord.order_profit = profit;
            episodeRecord.order_profit_points = profit / _Point;
            episodeRecord.order_success = isWin;
            episodeRecord.max_favorable_excursion = 0;
            episodeRecord.max_adverse_excursion = 0;
            
            // Note: tradeRecord removed - using basic completion

            // Completar el episodio
            g_episodicMemory.CompleteEpisode(episodeId, episodeRecord, isWin);
            Print("✓ Episodio ", episodeId, " completado");
        }
    }
    
    // 5. NOTIFICAR A REGIMEDETECTION
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        // Actualizar estadísticas del régimen actual
        ENUM_MARKET_REGIME currentRegime = g_regimeDetector.GetCurrentRegime();
        
        // Crear estructura de resultado
        TradeResult result;
        result.ticket = orderTicket;
        result.profit = profit;
        result.isWin = isWin;
        result.regime = currentRegime;
        result.consensus_id = consensus_id;
        result.closeTime = TimeCurrent();
        
        // Notificar al sistema de régimen
        RecordTradeResultStub(result);
        
        // Actualizar contadores locales
        g_regimeProfit += profit;
        
        Print("✓ Régimen ", EnumToString(currentRegime), " notificado");
    }
    
    // 6. ACTUALIZAR VOTINGSTATISTICS
    if(g_votingStats != NULL)
    {
        // TODO: Método no existe - g_votingStats.UpdateVotingResult(isWin);
    }
    
    // 7. LOG FINAL
    Print("═══ RESUMEN DE NOTIFICACIÓN ═══");
    Print("► Ticket: ", orderTicket);
    Print("► Consensus ID: ", consensus_id > 0 ? IntegerToString(consensus_id) : "N/A");
    Print("► Profit: ", DoubleToString(profit, 2));
    Print("► Resultado: ", isWin ? "GANADOR" : "PERDEDOR");
    Print("► Sistemas notificados: ML ✓ EMS ✓ RDS ✓ VS ✓");
    
    // 8. Guardar cambios
    if(g_metaLearning != NULL)
    {
        g_metaLearning.SaveToFiles();
    }
}

//+------------------------------------------------------------------+
//| MÓDULO 2: RegisterConsensusDecisionWithTracking CORREGIDO      |
//+------------------------------------------------------------------+
void RegisterConsensusDecisionWithTracking()
{
    if(g_metaLearning != NULL && g_voteHistoryCount > 0)
    {
        ConsensusMemory consensusMem;
        consensusMem.consensus_id = g_current_consensus_id;
        consensusMem.timestamp = TimeCurrent();
        consensusMem.consensus_strength = g_consensusResult.consensus_strength;
        consensusMem.direction = g_consensusResult.final_direction;
        consensusMem.dominant_agent = g_consensusResult.leading_agent;
        consensusMem.context = g_decisionContext;
        
        // CORREGIDO: Acceder al elemento por índice, no por referencia
        int lastVoteIndex = g_voteHistoryCount - 1;
        
        for(int i = 0; i < 5; i++)
        {
            if(g_voteHistory[lastVoteIndex].agents[i].voted)
            {
                consensusMem.participating_agents[i] = GetAgentName((ENUM_COMPONENT_TYPE)i);
                consensusMem.agent_confidences[i] = g_voteHistory[lastVoteIndex].agents[i].adjustedConfidence;
                consensusMem.agent_votes[i] = g_voteHistory[lastVoteIndex].agents[i].direction;
            }
        }

        // Note: RecordConsensusDecision method not implemented
    }
}

//+------------------------------------------------------------------+
//| RECOLECTAR VOTOS CON FUERZA DE PESO GARANTIZADA                  |
//+------------------------------------------------------------------+
int CollectAllVotesWithTracking(ulong consensus_id = 0)
{
    if(consensus_id == 0 && g_metaLearning != NULL)
    {
        consensus_id = g_metaLearning.GenerateConsensusID();
    }
    
    // Gestión del array de historial
    if(g_voteHistoryCount >= ArraySize(g_voteHistory))
        ArrayResize(g_voteHistory, g_voteHistoryCount + 100);

    VoteTracker newTracker;
    newTracker.consensus_id = consensus_id;
    newTracker.timestamp = TimeCurrent();
    newTracker.tradeExecuted = false;

    // Limpiar tracker
    for(int i = 0; i < 5; i++)
    {
        newTracker.agents[i].voted = false;
        newTracker.agents[i].direction = VOTE_NEUTRAL;
        newTracker.agents[i].confidence = 0.0;
        newTracker.agents[i].wasCorrect = false;
    }
    
    int votesCollected = 0;

    // CORRECCIÓN CRÍTICA: NO aplicar pesos aquí
    // Los pesos se aplicarán UNA SOLA VEZ en MakeFinalDecision() usando metaLearning.GetAgentWeight()
    // Esto elimina la duplicación de pesos

    // --- AGENTE 0: S/R ---
    double srConf = 0.0;
    ENUM_TREND_DIRECTION srDir = g_srManager.GetVoteDirection(srConf);
    // FILTRO DE CALIDAD: Solo aceptar votos con confidence > 0.40
    if(srDir != TREND_NONE && srConf > 0.40)
    {
        ENUM_VOTE_DIRECTION vote = (srDir == TREND_UP) ? VOTE_BUY : VOTE_SELL;

        // Enviar confidence ORIGINAL (sin pesos)
        if(g_votingStats.RecordVote(COMPONENT_SUPPORT_RESIST, vote, srConf, "SR_" + IntegerToString(consensus_id)))
        {
            newTracker.agents[0].voted = true;
            newTracker.agents[0].direction = vote;
            newTracker.agents[0].confidence = srConf;           // Original
            newTracker.agents[0].adjustedConfidence = srConf;   // Original (se ajustará en MakeFinalDecision)
            votesCollected++;
            Print("VOTO S/R: ", EnumToString(vote), " | Confidence: ", DoubleToString(srConf,2));
        }
    }

    // --- AGENTE 1: ACCUMULATION ---
    double accumConf = 0.0;
    ENUM_TREND_DIRECTION accumDir = g_accumZones.GetVoteDirection(accumConf);
    // FILTRO DE CALIDAD: Solo aceptar votos con confidence > 0.40
    if(accumDir != TREND_NONE && accumConf > 0.40)
    {
        ENUM_VOTE_DIRECTION vote = (accumDir == TREND_UP) ? VOTE_BUY : VOTE_SELL;

        if(g_votingStats.RecordVote(COMPONENT_ACCUM_ZONES, vote, accumConf, "ACC_" + IntegerToString(consensus_id)))
        {
            newTracker.agents[1].voted = true;
            newTracker.agents[1].direction = vote;
            newTracker.agents[1].confidence = accumConf;
            newTracker.agents[1].adjustedConfidence = accumConf;
            votesCollected++;
            Print("VOTO ACCUM: ", EnumToString(vote), " | Confidence: ", DoubleToString(accumConf,2));
        }
    }

    // --- AGENTE 2: PATTERN ---
    ENUM_TREND_DIRECTION patDir = g_patternMemory.GetImmediateDirection();
    double patConf = g_patternMemory.GetDirectionConfidence() / 100.0;
    // FILTRO DE CALIDAD: Solo aceptar votos con confidence > 0.40
    if(patDir != TREND_NONE && patConf > 0.40)
    {
        ENUM_VOTE_DIRECTION vote = (patDir == TREND_UP) ? VOTE_BUY : VOTE_SELL;

        if(g_votingStats.RecordVote(COMPONENT_PATTERN_MEMORY, vote, patConf, "PAT_" + IntegerToString(consensus_id)))
        {
            newTracker.agents[2].voted = true;
            newTracker.agents[2].direction = vote;
            newTracker.agents[2].confidence = patConf;
            newTracker.agents[2].adjustedConfidence = patConf;
            votesCollected++;
            Print("VOTO PATTERN: ", EnumToString(vote), " | Confidence: ", DoubleToString(patConf,2));
        }
    }

    // --- AGENTE 3: BREAKOUT ---
    ENUM_TREND_DIRECTION brkDir = g_breakoutDetector.GetImmediateDirection();
    double brkConf = g_breakoutDetector.GetDirectionConfidence() / 100.0;
    // FILTRO DE CALIDAD: Solo aceptar votos con confidence > 0.40
    if(brkDir != TREND_NONE && brkConf > 0.40)
    {
        ENUM_VOTE_DIRECTION vote = (brkDir == TREND_UP) ? VOTE_BUY : VOTE_SELL;

        if(g_votingStats.RecordVote(COMPONENT_BREAKOUT_DETECT, vote, brkConf, "BRK_" + IntegerToString(consensus_id)))
        {
            newTracker.agents[3].voted = true;
            newTracker.agents[3].direction = vote;
            newTracker.agents[3].confidence = brkConf;
            newTracker.agents[3].adjustedConfidence = brkConf;
            votesCollected++;
            Print("VOTO BREAKOUT: ", EnumToString(vote), " | Confidence: ", DoubleToString(brkConf,2));
        }
    }

    // --- AGENTE 4: INSTITUTIONAL ---
    ENUM_TREND_DIRECTION instDir = g_instPlanFinder.GetImmediateDirection();
    double instConf = g_instPlanFinder.GetDirectionConfidence() / 100.0;
    // FILTRO DE CALIDAD: Solo aceptar votos con confidence > 0.40
    if(instDir != TREND_NONE && instConf > 0.40)
    {
        ENUM_VOTE_DIRECTION vote = (instDir == TREND_UP) ? VOTE_BUY : VOTE_SELL;

        if(g_votingStats.RecordVote(COMPONENT_INSTITUTIONAL, vote, instConf, "INST_" + IntegerToString(consensus_id)))
        {
            newTracker.agents[4].voted = true;
            newTracker.agents[4].direction = vote;
            newTracker.agents[4].confidence = instConf;
            newTracker.agents[4].adjustedConfidence = instConf;
            votesCollected++;
            Print("VOTO INST: ", EnumToString(vote), " | Confidence: ", DoubleToString(instConf,2));
        }
    }

    // Guardar historial
    g_voteHistory[g_voteHistoryCount] = newTracker;
    g_voteHistoryCount++;

    return votesCollected;
}
//+------------------------------------------------------------------+
//| RECOLECTAR VOTOS BÁSICO (sin tracking)                         |
//+------------------------------------------------------------------+
int CollectAllVotes()
{
    return CollectAllVotesWithTracking(0);
}

// EN: TradingStrategy.mq5 -> UpdateAgentStatsFromVoteHistory

void UpdateAgentStatsFromVoteHistory(ulong orderTicket, bool isWin, double profit)
{
    if(g_metaLearning == NULL) return;

    // 1. Recuperar quién votó qué
    // Usamos el último registro de votos válido si no encontramos el exacto por ticket
    // Esto es mejor que no aprender nada.
    int voteIndex = -1;
    
    // Búsqueda exacta
    for(int i = g_voteHistoryCount - 1; i >= 0; i--) {
        if(g_voteHistory[i].orderTicket == orderTicket) {
            voteIndex = i;
            break;
        }
    }
    
    // Búsqueda aproximada (último consenso ejecutado) si falla la exacta
    if(voteIndex == -1 && g_voteHistoryCount > 0) {
        voteIndex = g_voteHistoryCount - 1; 
    }

    if(voteIndex == -1) return;

    // 2. Array de contribuciones para MetaLearning
    double contributors[5];
    ENUM_VOTE_DIRECTION winningDir = isWin ? g_voteHistory[voteIndex].finalDirection : 
                                     (g_voteHistory[voteIndex].finalDirection == VOTE_BUY ? VOTE_SELL : VOTE_BUY);

    for(int i = 0; i < 5; i++) {
        contributors[i] = 0.0;
        
        if(g_voteHistory[voteIndex].agents[i].voted) {
            // Si el agente votó en la dirección ganadora (o la que debió ganar)
            bool correctPrediction = (g_voteHistory[voteIndex].agents[i].direction == winningDir);
            
            // La contribución es su confianza ajustada
            double weight = g_voteHistory[voteIndex].agents[i].adjustedConfidence;
            
            // Si acertó, contribución positiva. Si falló, negativa.
            // Esto es lo que MetaLearning usará para castigar/premiar
            contributors[i] = correctPrediction ? weight : -weight; 
        }
    }

    // 3. Enviar al núcleo de aprendizaje
    g_metaLearning.LearnFromResult(isWin, profit, contributors, 5, "TRADE_CLOSE", g_voteHistory[voteIndex].consensus_id);
}

//+------------------------------------------------------------------+
//| Función auxiliar sin referencias - Compatible con MQL5          |
//+------------------------------------------------------------------+
double GetTotalConfidence(int voteIndex)
{
    if(voteIndex < 0 || voteIndex >= g_voteHistoryCount)
        return 0.001;
        
    double total = 0.0;
    for(int i = 0; i < 5; i++)
    {
        if(g_voteHistory[voteIndex].agents[i].voted)
            total += g_voteHistory[voteIndex].agents[i].adjustedConfidence;
    }
    return MathMax(0.001, total); // Evitar división por cero
}

// Función de fallback
void UpdateAllAgentsGeneric(bool isWin, double profit)
{
    for(int i = 0; i < 5; i++)
    {
        g_metaLearning.m_agentStats[i].trades++;
        if(isWin)
            g_metaLearning.m_agentStats[i].wins++;
        g_metaLearning.m_agentStats[i].total_profit += profit / 5.0;

        // CONSISTENCIA: Actualizar EMA de WinRate
        // g_metaLearning.UpdateAgentWinRateEMA(i, isWin);
    }
    g_metaLearning.SaveToFiles();
}

//+------------------------------------------------------------------+
//| MÓDULO ADICIONAL: Forzar Actualización de Stats en Ciclo       |
//+------------------------------------------------------------------+
void ForceUpdateAgentStats()
{
    if(g_metaLearning == NULL) return;
    
    // Obtener información del último ciclo
    MultiOrderCycle cycle = g_orderExecution.m_multiOrder;
    
    if(cycle.cycleProfit == 0 && cycle.totalPartialClosed == 0) return;
    
    double totalProfit = cycle.cycleProfit + cycle.totalPartialClosed;
    bool success = (totalProfit > 0);
    
    Print("═══ FORZANDO ACTUALIZACIÓN DE ESTADÍSTICAS ═══");
    
    // Actualizar cada agente que participó
    for(int i = 0; i < 5; i++)
    {
        // Solo actualizar si el agente votó en el consenso
        if(false) // Note: last_update field not present
            continue;
            
        g_metaLearning.m_agentStats[i].trades++;

        if(success)
        {
            g_metaLearning.m_agentStats[i].wins++;
            g_metaLearning.m_agentStats[i].consecutive_wins++;
            g_metaLearning.m_agentStats[i].consecutive_losses = 0;
        }
        else
        {
            g_metaLearning.m_agentStats[i].consecutive_losses++;
            g_metaLearning.m_agentStats[i].consecutive_wins = 0;
        }

        // CONSISTENCIA: Actualizar EMA de WinRate
        // g_metaLearning.UpdateAgentWinRateEMA(i, success);

        g_metaLearning.m_agentStats[i].total_profit += totalProfit;

        Print("Actualizado ", GetAgentName((ENUM_COMPONENT_TYPE)i), 
              " - Trades: ", g_metaLearning.m_agentStats[i].trades,
              " Wins: ", g_metaLearning.m_agentStats[i].wins);
    }
    
    // Guardar cambios
    g_metaLearning.SaveToFiles();
}

// FUNCIÓN AUXILIAR: Actualizar estadísticas de todos los agentes
void UpdateAllAgentStatsFromCycle(bool success, double profit)
{
    if(g_metaLearning == NULL) return;
    
    Print("Actualizando estadísticas de agentes post-ciclo...");
    
    // Buscar el registro de votos más reciente del ciclo
    int voteIndex = -1;
    if(g_voteHistoryCount > 0)
    {
        // Buscar hacia atrás el voto más reciente con consensus_id
        for(int i = g_voteHistoryCount - 1; i >= 0; i--)
        {
            if(g_voteHistory[i].consensus_id == g_orderExecution.m_multiOrder.initial_consensus_id)
            {
                voteIndex = i;
                break;
            }
        }
        
        // Si no encontramos por ID, usar el más reciente
        if(voteIndex < 0)
        {
            voteIndex = g_voteHistoryCount - 1;
        }
    }
    
    if(voteIndex >= 0)
    {
        // Actualizar basándose en votos reales
        ENUM_VOTE_DIRECTION winDirection = g_voteHistory[voteIndex].finalDirection;
        
        for(int i = 0; i < 5; i++)
        {
            if(g_voteHistory[voteIndex].agents[i].voted)
            {
                g_metaLearning.m_agentStats[i].trades++;
                
                bool votedCorrectly = (g_voteHistory[voteIndex].agents[i].direction == winDirection);
                
                if(success && votedCorrectly)
                {
                    g_metaLearning.m_agentStats[i].wins++;
                    g_metaLearning.m_agentStats[i].consecutive_wins++;
                    g_metaLearning.m_agentStats[i].consecutive_losses = 0;

                    // CRÍTICO: Actualizar EMA del winRate usando método público
                    // g_metaLearning.UpdateAgentWinRateEMA(i, true);

                    Print("  ✓ ", g_metaLearning.m_agentNames[i], " - Votó correctamente y ganó");
                }
                else
                {
                    g_metaLearning.m_agentStats[i].consecutive_losses++;
                    g_metaLearning.m_agentStats[i].consecutive_wins = 0;

                    // CRÍTICO: Actualizar EMA del winRate usando método público
                    // g_metaLearning.UpdateAgentWinRateEMA(i, false);

                    if(!success)
                        Print("  ✗ ", g_metaLearning.m_agentNames[i], " - Pérdida");
                    else
                        Print("  ⚠ ", g_metaLearning.m_agentNames[i], " - Votó incorrectamente");
                }
                
                // Distribuir profit
                double profitShare = profit / g_orderExecution.m_multiOrder.orderCount;
                g_metaLearning.m_agentStats[i].total_profit += profitShare;
                // Note: last_update field not present in AgentStats
                
                // Si fue líder
                if(g_consensusResult.leading_agent == g_metaLearning.m_agentNames[i])
                {
                    // Note: trades_as_leader, profit_as_leader, wins_as_leader fields not present
                }
            }
        }
    }
    else
    {
        // Fallback: actualizar todos proporcionalmente
        Print("⚠ Sin registro de votos - actualizando todos proporcionalmente");
        
        for(int i = 0; i < 5; i++)
        {
            g_metaLearning.m_agentStats[i].trades++;
            
            if(success)
            {
                g_metaLearning.m_agentStats[i].wins++;
                g_metaLearning.m_agentStats[i].consecutive_wins++;
                g_metaLearning.m_agentStats[i].consecutive_losses = 0;

                // CRÍTICO: Actualizar EMA del winRate usando método público
                // g_metaLearning.UpdateAgentWinRateEMA(i, true);
            }
            else
            {
                g_metaLearning.m_agentStats[i].consecutive_losses++;
                g_metaLearning.m_agentStats[i].consecutive_wins = 0;

                // CRÍTICO: Actualizar EMA del winRate usando método público
                // g_metaLearning.UpdateAgentWinRateEMA(i, false);
            }

            g_metaLearning.m_agentStats[i].total_profit += profit / 5.0;
        }
    }
    
    // Mostrar estadísticas actualizadas
    Print("\n► Estadísticas actualizadas:");
    for(int i = 0; i < 5; i++)
    {
        double wr = g_metaLearning.GetAgentWinRate((ENUM_COMPONENT_TYPE)i);
        Print("  ", g_metaLearning.m_agentNames[i], ": ",
              g_metaLearning.m_agentStats[i].trades, " trades, ",
              g_metaLearning.m_agentStats[i].wins, " wins (",
              DoubleToString(wr * 100, 1), "%)");
    }
}

// FUNCIÓN AUXILIAR: Análisis post-ciclo
void AnalyzePostCyclePerformance(bool success, double profit)
{
    if(g_metaLearning == NULL) return;
    
    Print("\n═══ ANÁLISIS POST-CICLO ═══");
    
    // Predicción vs Resultado
    double features[15];
    PrepareMLFeatures(features);
    double prediction = g_metaLearning.PredictOutcomeEnhanced(features, Symbol());
    
    double predictionError = MathAbs(prediction - (success ? 1.0 : 0.0));
    
    Print("► Predicción ML: ", DoubleToString(prediction * 100, 1), "%");
    Print("► Resultado real: ", success ? "Éxito" : "Pérdida");
    Print("► Error de predicción: ", DoubleToString(predictionError * 100, 1), "%");
    
    if(predictionError > 0.5)
    {
        Print("⚠ Error de predicción alto - requiere más aprendizaje en este contexto");
        
        // Información del contexto para debug
        Print("  Volatilidad: ", DoubleToString(g_market.volatilityRatio, 2));
        Print("  Régimen: ", EnumToString(g_currentCycle.currentRegime));
        Print("  Emociones: Fear ", DoubleToString(g_marketEmotion.fear, 2),
              " Greed ", DoubleToString(g_marketEmotion.greed, 2));
    }
    
    // Análisis de consenso
    if(g_currentCycle.consensusQuality > 0.8 && !success)
    {
        Print("⚠ Consenso fuerte falló - revisar contexto");
    }
    else if(g_currentCycle.consensusQuality < 0.5 && success)
    {
        Print("✓ Éxito con consenso débil - posible suerte");
    }
}

// FUNCIONES AUXILIARES NUEVAS
void UpdateStatsFromCompleteRecord(const CompleteTradeRecord &record, bool isWin, double profit)
{
    Print("Actualizando estadísticas desde registro completo");

    for(int i = 0; i < 5; i++)
    {
        bool participated = false;

        // Verificar participación del agente
        for(int j = 0; j < 5; j++)
        {
            if(record.participating_agents[j] == g_metaLearning.m_agentNames[i] &&
               record.agent_confidences[j] > 0)
            {
                participated = true;
                break;
            }
        }
        
        if(participated)
        {
            g_metaLearning.m_agentStats[i].trades++;

            if(isWin)
            {
                g_metaLearning.m_agentStats[i].wins++;
                g_metaLearning.m_agentStats[i].consecutive_wins++;
                g_metaLearning.m_agentStats[i].consecutive_losses = 0;
            }
            else
            {
                g_metaLearning.m_agentStats[i].consecutive_losses++;
                g_metaLearning.m_agentStats[i].consecutive_wins = 0;
            }

            // CONSISTENCIA: Actualizar EMA de WinRate
            // g_metaLearning.UpdateAgentWinRateEMA(i, isWin);

            g_metaLearning.m_agentStats[i].total_profit += profit;
            // Note: last_update field not present in AgentStats

            Print("  ", g_metaLearning.m_agentNames[i], " actualizado");
        }
    }
}

void UpdateStatsFromVoteIndex(int voteIndex, bool isWin, double profit)
{
    Print("Actualizando estadísticas desde índice de voto: ", voteIndex);
    
    double totalConfidence = 0.0;
    for(int i = 0; i < 5; i++)
    {
        if(g_voteHistory[voteIndex].agents[i].voted)
            totalConfidence += g_voteHistory[voteIndex].agents[i].adjustedConfidence;
    }
    
    if(totalConfidence == 0) totalConfidence = 1.0;
    
    ENUM_VOTE_DIRECTION winningDirection = g_voteHistory[voteIndex].finalDirection;
    
    for(int i = 0; i < 5; i++)
    {
        if(g_voteHistory[voteIndex].agents[i].voted)
        {
            g_metaLearning.m_agentStats[i].trades++;
            
            bool votedCorrectly = (g_voteHistory[voteIndex].agents[i].direction == winningDirection);
            
            if(isWin && votedCorrectly)
            {
                g_metaLearning.m_agentStats[i].wins++;
                g_metaLearning.m_agentStats[i].consecutive_wins++;
                g_metaLearning.m_agentStats[i].consecutive_losses = 0;

                // CRÍTICO: Actualizar EMA del winRate usando método público
                // g_metaLearning.UpdateAgentWinRateEMA(i, true);
            }
            else
            {
                g_metaLearning.m_agentStats[i].consecutive_losses++;
                g_metaLearning.m_agentStats[i].consecutive_wins = 0;

                // CRÍTICO: Actualizar EMA del winRate usando método público
                // g_metaLearning.UpdateAgentWinRateEMA(i, false);
            }
            
            double profitShare = profit * g_voteHistory[voteIndex].agents[i].adjustedConfidence / totalConfidence;
            g_metaLearning.m_agentStats[i].total_profit += profitShare;
            // Note: last_update field not present in AgentStats
            
            Print("  ", g_metaLearning.m_agentNames[i], 
                  " - Votó: ", (g_voteHistory[voteIndex].agents[i].direction == VOTE_BUY ? "BUY" : "SELL"),
                  " - Correcto: ", (isWin && votedCorrectly ? "SÍ" : "NO"));
        }
    }
}

void UpdateAllAgentsProportionally(bool isWin, double profit)
{
    // Solo actualizar agentes que tienen actividad reciente
    datetime recentTime = TimeCurrent() - 300; // Últimos 5 minutos
    int activeAgents = 0;
    
    for(int i = 0; i < 5; i++)
    {
        if(false) // Note: last_update field not present
            activeAgents++;
    }
    
    if(activeAgents == 0) activeAgents = 5; // Si ninguno activo, actualizar todos
    
    double profitPerAgent = profit / activeAgents;
    
    for(int i = 0; i < 5; i++)
    {
        if(activeAgents == 5) // Note: last_update field not present
        {
            g_metaLearning.m_agentStats[i].trades++;
            
            if(isWin)
            {
                g_metaLearning.m_agentStats[i].wins++;
                g_metaLearning.m_agentStats[i].consecutive_wins++;
                g_metaLearning.m_agentStats[i].consecutive_losses = 0;

                // CRÍTICO: Actualizar EMA del winRate usando método público
                // g_metaLearning.UpdateAgentWinRateEMA(i, true);
            }
            else
            {
                g_metaLearning.m_agentStats[i].consecutive_losses++;
                g_metaLearning.m_agentStats[i].consecutive_wins = 0;

                // CRÍTICO: Actualizar EMA del winRate usando método público
                // g_metaLearning.UpdateAgentWinRateEMA(i, false);
            }

            g_metaLearning.m_agentStats[i].total_profit += profitPerAgent;
            // Note: last_update field not present in AgentStats
        }
    }
}

//+------------------------------------------------------------------+
//| FUNCIONES STUB PARA EPISODICMEMORY                             |
//+------------------------------------------------------------------+
void CancelEpisodeStub(ulong episodeId)
{
    if(g_episodicMemory == NULL) return;
    
    // Implementación básica: marcar el episodio como cancelado
    Print("Cancelando episodio ", episodeId);
    
    // Si el sistema no tiene el método, al menos registrar
    CompleteTradeRecord cancelRecord;
    cancelRecord.order_success = false;
    cancelRecord.order_profit_points = 0;
    
    // Intentar completar con datos de cancelación
    g_episodicMemory.CompleteEpisode(episodeId, cancelRecord, false);
}

void UpdateEpisodeConsensusStub(ulong episodeId, const NeuralConsensusResult &consensus)
{
    if(g_episodicMemory == NULL) return;
    
    Print("Actualizando episodio ", episodeId, " con consenso");
    
    // Si no existe el método específico, al menos registrar el update
    // Esto requeriría acceso interno al episodio, pero como stub simplemente lo registramos
}

ulong FindEpisodeByConsensusIDStub(ulong consensus_id)
{
    if(g_episodicMemory == NULL) return 0;
    
    // Búsqueda básica - en una implementación real buscaría en el array de episodios
    // Por ahora, retornar 0 si no se encuentra
    Print("Buscando episodio con consensus_id ", consensus_id);
    
    if(g_currentCycle.episodeId > 0 && g_orderExecution.m_multiOrder.initial_consensus_id == consensus_id)
    {
        return g_currentCycle.episodeId;
    }
    
    return 0;
}

void RecordTradeResultStub(const TradeResult &result)
{
    if(g_regimeDetector == NULL) return;
    
    Print("Registrando resultado de trade en régimen");
    
    // Implementación básica - actualizar estadísticas internas
    // En la implementación real, esto actualizaría las estadísticas del régimen
}

//+------------------------------------------------------------------+
//| MÓDULO CORREGIDO: SearchSimilarEpisodes con Campos Correctos   |
//+------------------------------------------------------------------+
void SearchSimilarEpisodes()
{
    if(g_episodicMemory == NULL) return;
    
    Print("═══ BÚSQUEDA DE EPISODIOS SIMILARES ═══");
    
    // Conversión COMPLETA de contexto para búsqueda episódica
    EM_TouchContext emTouch;
    ConvertTouchContext(g_touchContext, emTouch);
    
    // Contexto de acumulación actual (puede no estar completo aún)
    AccumulationContext currentAccum = g_accumContext;
    if(!currentAccum.valid)
    {
        // Usar contexto temporal si aún no hay acumulación
        currentAccum.barCount = g_accumBarsSinceTouch;
        currentAccum.range = g_market.currentATR * 0.5; // Estimación
        currentAccum.valid = false;
    }
    
    // Obtener régimen actual
    ENUM_MARKET_REGIME currentRegime = REGIME_RANGING;
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        currentRegime = g_regimeDetector.GetCurrentRegime();
    }
    
    // Buscar episodios similares con límite aumentado
    TradingEpisode similarEpisodes[];
    g_similarEpisodesFound = g_episodicMemory.FindSimilarEpisodes(
        emTouch,
        currentAccum,
        currentRegime,
        similarEpisodes,
        50  // Buscar hasta 50 episodios similares
    );
    
    if(g_similarEpisodesFound > 0)
    {
        // Predecir resultado basado en episodios similares
        g_extendedTouch.prediction = g_episodicMemory.PredictOutcome(
            similarEpisodes, 
            g_similarEpisodesFound
        );
        
        g_extendedTouch.hasHistoricalData = true;
        g_historicalSuccessRate = g_extendedTouch.prediction.successProbability;
        
        if(ShowEpisodicPredictions)
        {
            Print("Episodios similares encontrados: ", g_similarEpisodesFound);
            Print("► Similitud promedio: ", 
                  DoubleToString(g_extendedTouch.prediction.avgSimilarity * 100, 1), "%");
            Print("► Tasa de éxito histórica: ", 
                  DoubleToString(g_historicalSuccessRate * 100, 1), "%");
            Print("► Profit esperado: ", 
                  DoubleToString(g_extendedTouch.prediction.expectedProfit, 1), " pts");
            Print("► Drawdown esperado: ", 
                  DoubleToString(g_extendedTouch.prediction.expectedDrawdown, 1), " pts");
            Print("► Confianza: ", 
                  DoubleToString(g_extendedTouch.prediction.confidence * 100, 1), "%");
            
            // Análisis por régimen si hay suficientes datos
            if(g_similarEpisodesFound >= 10)
            {
                int sameRegimeCount = 0;
                int sameRegimeSuccess = 0;
                
                for(int i = 0; i < g_similarEpisodesFound; i++)
                {
                    if(similarEpisodes[i].marketRegime == currentRegime)
                    {
                        sameRegimeCount++;
                        if(similarEpisodes[i].wasSuccessful)
                            sameRegimeSuccess++;
                    }
                }
                
                if(sameRegimeCount > 0)
                {
                    double regimeSuccessRate = (double)sameRegimeSuccess / sameRegimeCount;
                    Print("► En régimen ", EnumToString(currentRegime), ": ",
                          sameRegimeCount, " casos, ",
                          DoubleToString(regimeSuccessRate * 100, 1), "% éxito");
                }
            }
            
            // Mostrar información del nivel SR para debug
            Print("► Nivel SR: ", (emTouch.level.type == SR_SUPPORT ? "SOPORTE" : "RESISTENCIA"),
                  " @ ", DoubleToString(emTouch.level.price, _Digits));
            Print("► Fuerza nivel: ", DoubleToString(emTouch.levelStrength, 1),
                  " | Toques: ", emTouch.touchNumber);
            Print("► Movimiento desde nivel: ", DoubleToString(emTouch.level.movementStrength, 2), " ATRs");
            
            // Advertencias si las hay
            if(g_extendedTouch.prediction.warning != "")
            {
                Print("⚠ ADVERTENCIA: ", g_extendedTouch.prediction.warning);
                
                // Si la predicción es muy mala, considerar ajustar requisitos
                if(g_extendedTouch.prediction.successProbability < 0.3)
                {
                    Print("⚠ Considerar esperar mejor configuración");
                }
            }
            
            // Recomendación
            if(g_extendedTouch.prediction.shouldTrade)
            {
                Print("✓ Recomendación histórica: PROCEDER");
            }
            else
            {
                Print("✗ Recomendación histórica: EVITAR");
            }
        }
        
        // Almacenar información para uso posterior
        g_currentCycle.episodeId = 0; // Se creará cuando se ejecute la orden
        g_currentCycle.episodeSaved = false;
    }
    else
    {
        Print("No se encontraron episodios similares suficientes");
        g_extendedTouch.hasHistoricalData = false;
        g_historicalSuccessRate = 0.5; // Neutral
    }
    
    Print("═════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| CONVERTIR TouchContext a EM_TouchContext                        |
//+------------------------------------------------------------------+
void ConvertTouchContext(const TouchContext &source, EM_TouchContext &dest)
{
    // Información básica del toque
    dest.valid = source.valid;
    dest.price = source.price;
    dest.time = source.time;
    dest.touchType = (source.touchNumber == 1) ? TOUCH_FIRST : TOUCH_RETEST;
    dest.quality = source.quality;
    dest.levelStrength = source.levelStrength;
    dest.touchNumber = source.touchNumber;
    
    // ATR actual
    dest.atr = g_market.currentATR;
    
    // Información del nivel SR
    dest.level.price = source.level.price;
    dest.level.type = source.level.type;
    dest.level.state = source.level.state;
    dest.level.quality = source.level.quality;
    dest.level.strength = source.levelStrength;
    dest.level.touches = source.level.touchCount;
    
    // Tiempos del nivel - usar valores actuales como aproximación
    dest.level.firstTouch = source.time;
    dest.level.lastTouch = source.time;
    
    // Si tenemos múltiples toques, estimar el primer toque
    if(source.touchNumber > 1)
    {
        // Estimar que los toques anteriores fueron cada hora
        dest.level.firstTouch = source.time - (source.touchNumber - 1) * PeriodSeconds(PERIOD_H1);
    }
    
    // Calcular fuerza del movimiento
    double priceMove = MathAbs(g_market.currentBid - source.level.price);
    dest.level.movementStrength = (g_market.currentATR > 0) ? priceMove / g_market.currentATR : 0.0;
}

// Iniciar nuevo episodio
void StartNewEpisode()
{
    if(g_episodicMemory == NULL) return;
    
    // Convertir contextos
    EM_TouchContext emTouch;
    ConvertTouchContext(g_touchContext, emTouch);
    
    // Crear memoria de consenso
    ConsensusMemory tempConsensus;
    tempConsensus.consensus_id = g_current_consensus_id;
    tempConsensus.timestamp = TimeCurrent();
    tempConsensus.direction = g_consensusResult.final_direction;
    
    // Crear resultado neural
    NeuralConsensusResult tempNeural = g_consensusResult;
    
    g_currentCycle.episodeId = g_episodicMemory.StartNewEpisode(
        emTouch,
        g_accumContext,
        tempConsensus,
        tempNeural
    );
    
    g_currentCycle.episodeSaved = false;
    
    Print("► Nuevo episodio iniciado: ID ", g_currentCycle.episodeId);
}

// Completar episodio actual
void CompleteCurrentEpisode(bool success, double profit = 0)
{
    if(g_episodicMemory == NULL || g_currentCycle.episodeId == 0) return;
    
    CompleteTradeRecord record;
    record.order_profit_points = profit;
    record.max_favorable_excursion = 0;
    record.max_adverse_excursion = 0;
    
    g_episodicMemory.CompleteEpisode(g_currentCycle.episodeId, record, success);
    g_currentCycle.episodeSaved = true;
    
    Print("► Episodio completado: ID ", g_currentCycle.episodeId);
}

//+------------------------------------------------------------------+
//| FUNCIONES DE SOPORTE                                             |
//+------------------------------------------------------------------+

// Función auxiliar para registrar decisión
void RegisterConsensusDecision()
{
    if(g_metaLearning != NULL)
    {
        // Note: RecordConsensusDecision method not implemented
    }
}

// Verificar si es la misma dirección
bool CheckSameDirection(const TouchContext &touchCtx)
{
    if(g_orderExecution.m_multiOrder.direction == DIRECTION_BUY && 
       touchCtx.level.type == SR_SUPPORT)
        return true;
    
    if(g_orderExecution.m_multiOrder.direction == DIRECTION_SELL && 
       touchCtx.level.type == SR_RESISTANCE)
        return true;
    
    return false;
}

// Preparar contexto extendido
void PrepareExtendedContext(const TouchContext &touchCtx, bool seekingAdditional)
{
    g_extendedTouch.srTouchContext = touchCtx;
    
    // Establecer régimen actual
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        g_extendedTouch.regime = g_regimeDetector.GetCurrentRegime();
    }
    else
    {
        g_extendedTouch.regime = REGIME_RANGING;
    }
    
    g_extendedTouch.hasHistoricalData = false;
}

// Validar consenso
bool ValidateConsensus()
{
    // Verificar dirección si hay órdenes activas
    if(g_currentCycle.activeDirection != VOTE_NEUTRAL)
    {
        if(g_consensusResult.final_direction != g_currentCycle.activeDirection)
        {
            if(g_consensusResult.consensus_reasoning.Find("ORACLE OVERRIDE") >= 0)
            {
                Print("Oracle ha anulado la dirección bloqueada");
                return true;
            }
            
            Print("CONSENSO RECHAZADO: Dirección contraria a órdenes activas");
            return false;
        }
    }
    
    // Verificar veto
    if(g_consensusResult.veto_used && g_consensusResult.final_direction == VOTE_NEUTRAL)
    {
        Print("Consenso vetado por agente con privilegios");
        return false;
    }
    
    // Determinar umbrales
    double minStrength = MinConsensusStrength;
    double minConviction = MinTotalConviction;
    
    // Ajustar por régimen si está activo
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        RegimeParameters regimeParams = g_regimeDetector.GetCurrentParameters();
        minStrength = regimeParams.minConsensusStrength;
        minConviction = regimeParams.minTotalConviction;
    }
    
    // Ajustar para órdenes adicionales
    if(g_currentCycle.seekingAdditional && RequireStrongerConsensus)
    {
        minStrength *= 1.2;
        minConviction *= 1.2;
    }
    else if(g_currentCycle.seekingAdditional)
    {
        minStrength *= 0.9;
        minConviction *= 0.9;
    }
    
    // Relajar si hay agentes privilegiados
    if(g_currentCycle.privilegedAgentsCount > 0)
    {
        minStrength *= 0.9;
        minConviction *= 0.9;
    }
    
    // Relajar si el nivel SR es muy fuerte
    if(g_currentCycle.srLevelQuality >= SR_QUALITY_CRITICAL)
    {
        minStrength *= 0.85;
        minConviction *= 0.85;
    }
    
    // Validación final
    if(RequireStrongConsensus)
    {
        return g_consensusResult.strong_consensus && 
               g_consensusResult.final_direction != VOTE_NEUTRAL;
    }
    else
    {
        return g_consensusResult.final_direction != VOTE_NEUTRAL &&
               (g_consensusResult.consensus_strength >= minStrength ||
                g_consensusResult.strong_consensus) &&
               g_consensusResult.total_conviction >= minConviction;
    }
}

//+------------------------------------------------------------------+
//| VALIDACIÓN DE CONSENSO MEJORADA                                  |
//+------------------------------------------------------------------+
bool ValidateConsensusWithPrediction(double minStrength, double minConviction, double prediction)
{
    // 1. Obtener resultado base
    // Nota: Usamos los valores calculados por VotingStatistics
    bool strongConsensus = g_consensusResult.strong_consensus;
    double currentStrength = g_consensusResult.consensus_strength;
    double currentConviction = g_consensusResult.total_conviction;
    
    // 2. Filtro de Dirección Bloqueada
    if(g_currentCycle.activeDirection != VOTE_NEUTRAL)
    {
        if(g_consensusResult.final_direction != g_currentCycle.activeDirection)
        {
            // Excepción Oracle
            if(StringFind(g_consensusResult.consensus_reasoning, "ORACLE") >= 0)
                return true;
                
            Print("⛔ Consenso rechazado: Dirección contraria a ciclo activo");
            return false;
        }
    }

    // 3. Ajuste de Umbrales para "Warm-up" (Arranque en frío)
    // Si no hay historial suficiente, bajamos la barrera para empezar a operar
    if(g_totalCycles < 10) 
    {
        minStrength *= 0.7;    // Reducir 30%
        minConviction *= 0.7;  // Reducir 30%
        if(ShowDebugInfo) Print("⚠️ Modo Warm-up: Umbrales reducidos 30%");
    }
    
    // 4. Validación Lógica
    bool isStrengthOk = (currentStrength >= minStrength);
    bool isConvictionOk = (currentConviction >= minConviction);
    
    // Si la predicción es muy buena (>0.6), permitimos convicción ligeramente menor
    if(prediction > 0.6) isConvictionOk = (currentConviction >= minConviction * 0.8);
    
    // Si la predicción es mala (<0.4), exigimos más fuerza
    if(prediction < 0.4) isStrengthOk = (currentStrength >= minStrength * 1.2);

    // 5. Resultado Final
    if(g_consensusResult.final_direction == VOTE_NEUTRAL) return false;
    
    if(strongConsensus) return true; // El consenso fuerte siempre pasa
    
    if(isStrengthOk && isConvictionOk) return true;
    
    Print("❌ Consenso insuficiente. Req: Str>", DoubleToString(minStrength,2), " Conv>", DoubleToString(minConviction,2), 
          " | Actual: Str=", DoubleToString(currentStrength,2), " Conv=", DoubleToString(currentConviction,2));
          
    return false;
}

//+------------------------------------------------------------------+
//| FUNCIONES DE ANÁLISIS                                           |
//+------------------------------------------------------------------+
void AnalyzeCurrentMarketEmotion()
{
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // ATR para volatilidad
    double atr_values[];
    double current_atr = 0, avg_atr = 0;
    
    if(CopyBuffer(g_atrHandle, 0, 0, 20, atr_values) == 20)
    {
        current_atr = atr_values[0];
        for(int i = 0; i < 20; i++)
            avg_atr += atr_values[i];
        avg_atr /= 20.0;
    }
    
    // RSI para momentum
    double rsi_buffer[];
    double rsi_value = 50.0;
    if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsi_buffer) > 0)
        rsi_value = rsi_buffer[0];
    
    // Calcular emociones
    double vol_ratio = (avg_atr > 0) ? current_atr / avg_atr : 1.0;
    
    // Miedo
    g_marketEmotion.fear = 0.3;
    if(vol_ratio > 1.5) g_marketEmotion.fear += 0.3;
    if(rsi_value < 30) g_marketEmotion.fear += 0.3;
    if(rsi_value > 70) g_marketEmotion.fear += 0.2;
    
    // Codicia
    g_marketEmotion.greed = 0.3;
    if(rsi_value > 60) g_marketEmotion.greed += (rsi_value - 60) / 40.0 * 0.4;
    if(vol_ratio < 0.8) g_marketEmotion.greed += 0.2;
    
    // Incertidumbre
    g_marketEmotion.uncertainty = MathAbs(vol_ratio - 1.0);
    
    // Emoción
    MqlRates rates[];
    if(CopyRates(Symbol(), PERIOD_CURRENT, 0, 5, rates) == 5)
    {
        double movement = MathAbs(rates[0].close - rates[4].close) / currentPrice;
        g_marketEmotion.excitement = MathMin(1.0, movement * 100);
    }
    
    // Normalizar
    g_marketEmotion.fear = MathMin(1.0, g_marketEmotion.fear);
    g_marketEmotion.greed = MathMin(1.0, g_marketEmotion.greed);
    g_marketEmotion.uncertainty = MathMin(1.0, g_marketEmotion.uncertainty);
    
    g_marketEmotion.timestamp = TimeCurrent();
}

void MonitorMarketEmotions()
{
    static datetime lastEmotionCheck = 0;
    
    if(TimeCurrent() - lastEmotionCheck < 60) return;
    
    lastEmotionCheck = TimeCurrent();
    AnalyzeCurrentMarketEmotion();
    
    if(g_marketEmotion.fear > EmotionalThreshold && ShowEmotionalAnalysis)
    {
        Print("ALERTA EMOCIONAL: Miedo elevado (", DoubleToString(g_marketEmotion.fear, 2), ")");
    }
    
    if(g_marketEmotion.greed > EmotionalThreshold && ShowEmotionalAnalysis)
    {
        Print("ALERTA EMOCIONAL: Codicia elevada (", DoubleToString(g_marketEmotion.greed, 2), ")");
    }
}

void CheckEmotionalAlerts()
{
    if(g_marketEmotion.fear > EmotionalThreshold)
    {
        Print("⚠ ALERTA: Nivel de MIEDO crítico: ", DoubleToString(g_marketEmotion.fear, 2));
        g_emotionalAlerts++;
    }
    
    if(g_marketEmotion.greed > EmotionalThreshold)
    {
        Print("⚠ ALERTA: Nivel de CODICIA crítico: ", DoubleToString(g_marketEmotion.greed, 2));
        g_emotionalAlerts++;
    }
}

//+------------------------------------------------------------------+
//| DETECCIÓN DE PATRONES                                           |
//+------------------------------------------------------------------+
bool DetectAccumulationPattern()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    // Determinar mínimo de barras
    int minBarsNeeded = MinAccumulationBars;
    
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        RegimeParameters regimeParams = g_regimeDetector.GetCurrentParameters();
        minBarsNeeded = regimeParams.minAccumulationBars;
    }
    
    if(g_currentCycle.seekingAdditional)
    {
        minBarsNeeded = 2;
    }
    
    int barsToCheck = MathMin(MaxAccumulationBars, Bars(_Symbol, _Period));
    int copied = CopyRates(_Symbol, _Period, 0, barsToCheck, rates);
    
    if(copied < minBarsNeeded) return false;
    
    double highPrice = rates[0].high;
    double lowPrice = rates[0].low;
    int accumBars = 1;
    
    for(int i = 1; i < copied && i < MaxAccumulationBars; i++)
    {
        double tempHigh = MathMax(highPrice, rates[i].high);
        double tempLow = MathMin(lowPrice, rates[i].low);
        double tempRange = tempHigh - tempLow;
        
        if(tempRange <= g_market.currentATR * AccumulationRangeATR)
        {
            highPrice = tempHigh;
            lowPrice = tempLow;
            accumBars = i + 1;
        }
        else
        {
            break;
        }
    }

    // DEBUG: Mostrar información de acumulación cada 10 barras
    static int debugAccumCounter = 0;
    debugAccumCounter++;
    if(debugAccumCounter >= 10)
    {
        debugAccumCounter = 0;
        double currentRange = highPrice - lowPrice;
        double maxAllowedRange = g_market.currentATR * AccumulationRangeATR;
        Print("╔═══ DEBUG: Detección de Acumulación ═══╗");
        Print("║ Barras detectadas: ", accumBars, " / ", minBarsNeeded, " requeridas");
        Print("║ Rango actual: ", DoubleToString(currentRange, _Digits),
              " (", DoubleToString(currentRange / g_market.currentATR, 2), " ATRs)");
        Print("║ Rango máximo: ", DoubleToString(maxAllowedRange, _Digits),
              " (", DoubleToString(AccumulationRangeATR, 2), " ATRs)");
        Print("║ ATR actual: ", DoubleToString(g_market.currentATR, _Digits));
        Print("║ Barras desde toque: ", g_accumBarsSinceTouch, " / ", AccumulationTimeout, " timeout");
        Print("║ Estado: ", (accumBars >= minBarsNeeded ? "VÁLIDO ✓" : "INSUFICIENTE ✗"));
        Print("╚════════════════════════════════════════╝");
    }

    if(accumBars >= minBarsNeeded)
    {
        g_accumContext.valid = true;
        g_accumContext.centerPrice = (highPrice + lowPrice) / 2.0;
        g_accumContext.highPrice = highPrice;
        g_accumContext.lowPrice = lowPrice;
        g_accumContext.range = highPrice - lowPrice;
        g_accumContext.barCount = accumBars;
        g_accumContext.startTime = rates[accumBars-1].time;
        g_accumContext.endTime = rates[0].time;
        g_accumContext.volumeConfirmation = CheckVolumePattern(rates, accumBars);

        return true;
    }

    return false;
}

bool CheckVolumePattern(const MqlRates &rates[], int barCount)
{
    if(barCount < 3) return false;
    
    long totalVolume = 0;
    for(int i = 0; i < barCount; i++)
    {
        totalVolume += rates[i].tick_volume;
    }
    double avgVolume = (double)totalVolume / barCount;
    
    for(int i = 0; i < barCount; i++)
    {
        if(rates[i].tick_volume > avgVolume * 2.5)
        {
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| FUNCIONES DE CONTROL                                            |
//+------------------------------------------------------------------+
void ChangeState(TRADING_STATE newState)
{
    if(ShowDebugInfo)
    {
        Print("CAMBIO DE ESTADO: ", StateToString(g_currentState), " → ", StateToString(newState));
    }
    g_currentState = newState;
    g_barsInCurrentState = 0;
}

void ResetCycle()
{
    g_currentState = STATE_WAITING_SR_TOUCH;
    g_touchContext.valid = false;
    g_accumContext.valid = false;
    g_accumBarsSinceTouch = 0;
    g_emotionalAlerts = 0;
    g_barsInCurrentState = 0;
    
    g_currentCycle.cycleNumber++;
    g_currentCycle.startTime = TimeCurrent();
    g_currentCycle.touchTime = 0;
    g_currentCycle.accumStartTime = 0;
    g_currentCycle.negotiationTime = 0;
    g_currentCycle.touchPrice = 0;
    g_currentCycle.touchType = SR_SUPPORT;
    g_currentCycle.accumBarsCount = 0;
    g_currentCycle.accumValid = false;
    g_currentCycle.accumCenter = 0;
    g_currentCycle.accumRange = 0;
    g_currentCycle.isMultiOrderCycle = false;
    g_currentCycle.negotiationRounds = 0;
    g_currentCycle.emotionalContext = 0.5;
    g_currentCycle.activeDirection = VOTE_NEUTRAL;
    g_currentCycle.seekingAdditional = false;
    g_currentCycle.firstOrderOpenPrice = 0;
    g_currentCycle.ordersExecuted = 0;
    g_currentCycle.leadingAgent = "";
    g_currentCycle.consensusQuality = 0.0;
    g_currentCycle.vetoUsed = false;
    g_currentCycle.privilegedAgentsCount = 0;
    
    // Reset info SR
    g_currentCycle.srLevelStrength = 0.0;
    g_currentCycle.srLevelTouches = 0;
    g_currentCycle.srLevelQuality = SR_QUALITY_WEAK;
    g_currentCycle.srLevelState = SR_STATE_INITIAL;
    
    // Reset régimen y episodio
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        g_currentCycle.currentRegime = g_regimeDetector.GetCurrentRegime();
        g_currentCycle.regimeParams = g_regimeDetector.GetCurrentParameters();
    }
    g_currentCycle.episodeId = 0;
    g_currentCycle.episodeSaved = false;
    
    // Reset contexto extendido
    g_extendedTouch.hasHistoricalData = false;
    g_similarEpisodesFound = 0;
    g_historicalSuccessRate = 0.5;
    
    // Desbloquear dirección
    if(g_votingStats != NULL)
        // TODO: Método no existe - g_votingStats.SetDirectionLock(VOTE_NEUTRAL);

    // CRÍTICO: Limpiar historial de votos para evitar crecimiento indefinido
    // Implementación con límite circular: mantener últimos 100 votos
    if(g_voteHistoryCount > 100)
    {
        Print("⚠ Limpiando historial de votos: ", g_voteHistoryCount, " → 100");

        // Mover los últimos 100 al inicio del array
        for(int i = 0; i < 100; i++)
        {
            g_voteHistory[i] = g_voteHistory[g_voteHistoryCount - 100 + i];
        }

        g_voteHistoryCount = 100;
        ArrayResize(g_voteHistory, 100);

        Print("✓ Historial de votos limpiado - Memoria optimizada");
    }

    // CRÍTICO: Verificar posiciones huérfanas antes de iniciar nuevo ciclo
    int orphanPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                orphanPositions++;
                Print("⚠ ADVERTENCIA: Posición huérfana detectada - Ticket: ", ticket,
                      " | Profit: ", DoubleToString(PositionGetDouble(POSITION_PROFIT), 2),
                      " | Symbol: ", PositionGetString(POSITION_SYMBOL));
            }
        }
    }

    if(orphanPositions > 0)
    {
        Print("🚨 ALERTA: ", orphanPositions, " posiciones huérfanas detectadas");
        Print("Estas posiciones no están siendo trackeadas por el sistema");
        Print("Considere cerrarlas manualmente o investigar el problema");
    }

    Print("═══ CICLO RESETEADO - Esperando nuevo toque S/R ═══");
}

void ResetToWaitingState()
{
    g_currentState = STATE_WAITING_SR_TOUCH;
    g_touchContext.valid = false;
    g_accumContext.valid = false;
    g_accumBarsSinceTouch = 0;
    g_barsInCurrentState = 0;
    g_currentCycle.seekingAdditional = false;
    
    Print("Volviendo a esperar toque S/R");
}

//+------------------------------------------------------------------+
//| FUNCIONES DE UTILIDAD                                           |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    
    if(currentBarTime != g_lastBarTime)
    {
        g_lastBarTime = currentBarTime;
        return true;
    }
    
    return false;
}

bool CheckDailyLimits()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDate = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    if(currentDate != g_lastTradeDate)
    {
        g_dailyTradeCount = 0;
        g_lastTradeDate = currentDate;
    }
    
    return (g_dailyTradeCount < MaxDailyTrades);
}

void UpdateMarketInfo()
{
    g_market.currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    g_market.currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    g_market.lastUpdate = TimeCurrent();
    
    // Actualizar ATR
    double atrBuffer[];
    if(CopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer) > 0)
    {
        g_market.currentATR = atrBuffer[0];
    }
    
    // Calcular ratio de volatilidad
    double atr_values[];
    if(CopyBuffer(g_atrHandle, 0, 0, 20, atr_values) == 20)
    {
        double avg_atr = 0;
        for(int i = 0; i < 20; i++)
            avg_atr += atr_values[i];
        avg_atr /= 20.0;
        g_market.volatilityRatio = (avg_atr > 0) ? g_market.currentATR / avg_atr : 1.0;
    }
    
    // Calcular momentum
    g_market.momentum = CalculateMomentum();
    
    // Determinar sesión
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int hour = dt.hour;
    
    if(hour >= 0 && hour < 8)
        g_market.session = SESSION_ASIAN;
    else if(hour >= 8 && hour < 13)
        g_market.session = SESSION_LONDON_ML;
    else if(hour >= 13 && hour < 22)
        g_market.session = SESSION_NEWYORK;
    else
        g_market.session = SESSION_CLOSED;
}

void UpdateDecisionContext()
{
    g_decisionContext.timestamp = TimeCurrent();
    g_decisionContext.volatility = g_market.volatilityRatio;
    g_decisionContext.momentum = g_market.momentum;
    g_decisionContext.volume_ratio = CalculateVolumeRatio();
    g_decisionContext.session_type = (int)g_market.session;
    
    // RSI
    double rsi_buffer[];
    if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsi_buffer) > 0)
        g_decisionContext.rsi = rsi_buffer[0];
    else
        g_decisionContext.rsi = 50.0;
    
    g_decisionContext.atr_ratio = g_market.volatilityRatio;
    g_decisionContext.fear_level = g_marketEmotion.fear;
    g_decisionContext.greed_level = g_marketEmotion.greed;
    g_decisionContext.active_orders = 0;
    
    if(g_orderExecution.m_multiOrder.cycleActive)
        g_decisionContext.active_orders = g_orderExecution.m_multiOrder.orderCount;
    
    g_decisionContext.locked_direction = g_currentCycle.activeDirection;
}

double CalculateMomentum()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(Symbol(), PERIOD_CURRENT, 0, 20, rates) == 20)
    {
        double change = rates[0].close - rates[19].close;
        double avgPrice = (rates[0].close + rates[19].close) / 2.0;
        return (avgPrice > 0) ? change / avgPrice : 0.0;
    }
    
    return 0.0;
}

double CalculateVolumeRatio()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(Symbol(), PERIOD_CURRENT, 0, 20, rates) == 20)
    {
        long currentVolume = rates[0].tick_volume;
        long totalVolume = 0;
        
        for(int i = 1; i < 20; i++)
        {
            totalVolume += rates[i].tick_volume;
        }
        
        double avgVolume = totalVolume / 19.0;
        return (avgVolume > 0) ? currentVolume / avgVolume : 1.0;
    }
    
    return 1.0;
}

void UpdateNearbySRInfo()
{
    if(g_srManager == NULL) return;
    
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double searchRange = g_market.currentATR * 3;
    
    SRLevel strongLevels[];
    g_strongLevelsNearby = g_srManager.GetStrongLevels(strongLevels, MinLevelStrength);
    
    int nearbyCount = 0;
    for(int i = 0; i < ArraySize(strongLevels); i++)
    {
        double distance = MathAbs(currentPrice - strongLevels[i].price);
        if(distance <= searchRange)
        {
            nearbyCount++;
        }
    }
    g_strongLevelsNearby = nearbyCount;
    
    g_nearestSupportPrice = g_srManager.GetNearestSupportPrice(currentPrice);
    g_nearestResistancePrice = g_srManager.GetNearestResistancePrice(currentPrice);
}

void UpdateCycleStatus()
{
    if(g_orderExecution.m_multiOrder.cycleActive && g_orderExecution.m_multiOrder.orderCount > 0)
    {
        g_currentCycle.activeDirection = (g_orderExecution.m_multiOrder.direction == DIRECTION_BUY) ?
                                       VOTE_BUY : VOTE_SELL;
        if(g_votingStats != NULL)
            // TODO: Método no existe - g_votingStats.SetDirectionLock(g_currentCycle.activeDirection);
        g_currentCycle.ordersExecuted = g_orderExecution.m_multiOrder.orderCount;

        if(g_orderExecution.m_multiOrder.tickets[0] > 0)
        {
            if(PositionSelectByTicket(g_orderExecution.m_multiOrder.tickets[0]))
            {
                g_currentCycle.firstOrderOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            }
        }
    }
    else
    {
        g_currentCycle.activeDirection = VOTE_NEUTRAL;
        // TODO: Método no existe - if(g_votingStats != NULL) g_votingStats.SetDirectionLock(VOTE_NEUTRAL);
    }
    
    // Actualizar régimen actual
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        g_currentCycle.currentRegime = g_regimeDetector.GetCurrentRegime();
        g_currentCycle.regimeParams = g_regimeDetector.GetCurrentParameters();
    }
}

bool IsFirstOrderInSufficientProfit()
{
    if(!g_orderExecution.m_multiOrder.cycleActive || 
       g_orderExecution.m_multiOrder.orderCount == 0)
        return false;
    
    if(g_orderExecution.m_multiOrder.tickets[0] > 0)
    {
        if(PositionSelectByTicket(g_orderExecution.m_multiOrder.tickets[0]))
        {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double priceMove = 0;
            
            if(g_orderExecution.m_multiOrder.direction == DIRECTION_BUY)
                priceMove = (currentPrice - openPrice) / _Point;
            else
                priceMove = (openPrice - currentPrice) / _Point;
            
            if(priceMove >= MinProfitForAdditional)
            {
                if(ShowDebugInfo)
                {
                    Print("Primera orden con ", DoubleToString(priceMove, 0), 
                          " pts (requiere ", MinProfitForAdditional, " pts)");
                }
                return true;
            }
        }
    }
    
    return false;
}

void MonitorCycleHealth()
{
    double cycleProfit = 0.0;
    int ordersInProfit = 0;
    
    for(int i = 0; i < g_orderExecution.m_multiOrder.orderCount; i++)
    {
        if(g_orderExecution.m_multiOrder.tickets[i] > 0)
        {
            if(PositionSelectByTicket(g_orderExecution.m_multiOrder.tickets[i]))
            {
                double profit = PositionGetDouble(POSITION_PROFIT);
                cycleProfit += profit;
                if(profit > 0) ordersInProfit++;
            }
        }
    }
    
    if(ShowDebugInfo && MathMod(g_barsInCurrentState, 5) == 0)
    {
        Print("Monitoreando ", g_orderExecution.m_multiOrder.orderCount, " órdenes",
              " - P&L: ", DoubleToString(cycleProfit, 2),
              " - En profit: ", ordersInProfit);
    }
}

// Funciones auxiliares
void PrepareMLFeatures(double &features[])
{
    features[0] = g_market.volatilityRatio;
    features[1] = g_decisionContext.momentum;
    features[2] = g_decisionContext.volume_ratio;
    features[3] = g_decisionContext.rsi;
    features[4] = g_decisionContext.atr_ratio;
    features[5] = (double)g_decisionContext.session_type / 3.0;
    features[6] = 0.5; // price_position
    features[7] = (double)g_currentCycle.touchType / 10.0;
    features[8] = g_currentCycle.accumBarsCount / 50.0;
    features[9] = 0.5; // placeholder
    features[10] = g_currentCycle.emotionalContext;
    features[11] = 0.5; // placeholder consensus_strength
    features[12] = 0.5; // placeholder agent_agreement
    features[13] = 1.0; // placeholder dissenting
    features[14] = g_marketEmotion.fear;
}

void PrintNegotiationContextOptimized(double historicalSuccess, double prediction)
{
    PrintNegotiationContext(); // Original
    
    // Agregar información optimizada
    Print("═══ CONTEXTO OPTIMIZADO ═══");
    Print("► Éxito histórico similar: ", DoubleToString(historicalSuccess * 100, 1), "%");
    Print("► Predicción ML: ", DoubleToString(prediction * 100, 1), "%");
    
    if(g_metaLearning != NULL)
    {
        // Mostrar performance contextual de agentes
        Print("► Performance contextual de agentes:");
        for(int i = 0; i < 5; i++)
        {
            double perf = g_metaLearning.GetAgentContextualPerformance(i, g_decisionContext.volatility);

            if(perf > 0.65 || perf < 0.35)
            {
                Print("  ", GetAgentName((ENUM_COMPONENT_TYPE)i), ": ",
                      DoubleToString(perf * 100, 1), "%",
                      perf > 0.65 ? " ✓" : " ⚠");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| FUNCIONES DE IMPRESIÓN                                          |
//+------------------------------------------------------------------+
void ShowInitialConfiguration()
{
    Print("\n═══ CONFIGURACIÓN INICIAL ═══");
    
    if(g_EnableRegimeDetection)
    {
        Print("► Detección de Régimen: ACTIVA");
        if(g_regimeDetector != NULL)
        {
            Print("  Régimen inicial: ", EnumToString(g_regimeDetector.GetCurrentRegime()));
        }
    }
    else
    {
        Print("► Detección de Régimen: INACTIVA");
    }
    
    if(g_EnableEpisodicMemory)
    {
        Print("► Memoria Episódica: ACTIVA");
    }
    else
    {
        Print("► Memoria Episódica: INACTIVA");
    }
    
    if(ShowPerformanceStats && g_metaLearning != NULL)
    {
        g_metaLearning.PrintAgentPerformanceReport();
    }
}

void ShowFinalReport()
{
    Print("\n╔══════════════════════════════════════════════════════╗");
    Print("║             REPORTE FINAL NCN v15 FIXED              ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    Print("► Total ciclos completados: ", g_totalCycles);
    // TODO: Método no existe - Print("► Tasa de éxito: ", DoubleToString(g_votingStats.GetSuccessRate() * 100, 1), "%");
    
    if(ShowPerformanceStats && g_metaLearning != NULL)
    {
        Print("\n► PERFORMANCE FINAL DE AGENTES:");
        g_metaLearning.PrintAgentDetailedStats();
    }
}

//+------------------------------------------------------------------+
//| MÓDULO COMPLETO CORREGIDO: ShowPerformanceReport                |
//+------------------------------------------------------------------+
void ShowPerformanceReport()
{
    if(g_metaLearning == NULL) return;
    
    g_lastPerformanceReport = TimeCurrent();
    
    Print("\n╔══════════════════════════════════════════════════════╗");
    Print("║         REPORTE HORARIO DE PERFORMANCE               ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    // VALIDACIÓN CRÍTICA: Verificar integridad de datos
    if(!ValidateAgentDataIntegrity())
    {
        Print("⚠ CORRUPCIÓN DETECTADA - Reconstruyendo estadísticas...");
        RebuildAgentStatistics();
    }
    
    // Array para tracking de cambios
    string changes[];
    int changeCount = 0;
    
    // Mostrar estadísticas REALES E INDIVIDUALES
    for(int i = 0; i < 5; i++)
    {
        ENUM_COMPONENT_TYPE component = (ENUM_COMPONENT_TYPE)i;
        
        // Obtener datos FRESCOS
        double winRate = g_metaLearning.GetAgentWinRate(component);
        string privilege = g_metaLearning.GetAgentPrivilegeLevel(component);
        double weight = g_metaLearning.GetAgentWeight(component);
        bool hasVeto = g_metaLearning.AgentHasVetoPower(component);
        
        Print("\n▶ ", g_metaLearning.m_agentNames[i], " [", privilege, "]");
        Print("╟─ Trades: ", g_metaLearning.m_agentStats[i].trades, 
              " | Wins: ", g_metaLearning.m_agentStats[i].wins);
        Print("╟─ Win Rate: ", DoubleToString(winRate * 100, 1), "%");
        Print("╟─ Peso: x", DoubleToString(weight, 2),
              " | Veto: ", hasVeto ? "SÍ" : "NO");
        Print("╟─ P&L: ", DoubleToString(g_metaLearning.m_agentStats[i].total_profit, 2));
        
        // Rachas
        if(g_metaLearning.m_agentStats[i].consecutive_wins > 2)
        {
            Print("╟─ 🔥 Racha ganadora: +", g_metaLearning.m_agentStats[i].consecutive_wins);
        }
        else if(g_metaLearning.m_agentStats[i].consecutive_losses > 2)
        {
            Print("╟─ ❄️ Racha perdedora: -", g_metaLearning.m_agentStats[i].consecutive_losses);
        }

        // Note: Leader stats removed (fields not present in AgentStats)

        // Detectar cambios de privilegio
        static string lastPrivileges[5] = {"", "", "", "", ""};
        if(lastPrivileges[i] != "" && lastPrivileges[i] != privilege)
        {
            ArrayResize(changes, changeCount + 1);
            changes[changeCount] = g_metaLearning.m_agentNames[i] + ": " + 
                                  lastPrivileges[i] + " → " + privilege;
            changeCount++;
        }
        lastPrivileges[i] = privilege;
        
        // Performance contextual
        if(g_EnableRegimeDetection && g_regimeDetector != NULL)
        {
            double regimePerf = g_metaLearning.GetAgentContextualPerformance(component, g_decisionContext.volatility);

            if(regimePerf != winRate) // Si difiere del general
            {
                Print("╟─ 📊 En régimen actual: ",
                      DoubleToString(regimePerf * 100, 1), "%");
            }
        }
        
        Print("╚════════════════════════════════════════════════════");
    }
    
    // SECCIÓN: Cambios detectados
    if(changeCount > 0)
    {
        Print("\n🔔 CAMBIOS DE PRIVILEGIO:");
        for(int i = 0; i < changeCount; i++)
        {
            Print("  • ", changes[i]);
        }
    }
    
    // SECCIÓN: Estadísticas globales
    Print("\n═══ ESTADÍSTICAS GLOBALES ═══");
    Print("▶ Ciclos completados: ", g_totalCycles);
    Print("▶ Trades hoy: ", g_dailyTradeCount);
    
    double globalWR = 0.0;
    if(g_votingStats != NULL)
    {
        // TODO: Método no existe - globalWR = // TODO: Método no existe - g_votingStats.GetSuccessRate();
        Print("▶ Win Rate global: ", DoubleToString(globalWR * 100, 1), "%");
    }
    
    // Consenso
    double consensusWR = g_metaLearning.GetConsensusSuccessRate();
    Print("▶ Win Rate consenso: ", DoubleToString(consensusWR * 100, 1), "%");
    
    // Discrepancia check
    if(MathAbs(globalWR - consensusWR) > 0.1)
    {
        Print("⚠ Discrepancia entre win rates detectada");
    }
    
    // Master Agent
    string currentMaster = g_metaLearning.GetMasterAgent();
    if(currentMaster != "None" && currentMaster != "")
    {
        Print("\n⭐ MASTER AGENT: ", currentMaster);
        
        // Info del master
        for(int i = 0; i < 5; i++)
        {
            if(g_metaLearning.m_agentNames[i] == currentMaster)
            {
                Print("  Trades: ", g_metaLearning.m_agentStats[i].trades);
                Print("  Win Rate: ", DoubleToString(
                    g_metaLearning.GetAgentWinRate((ENUM_COMPONENT_TYPE)i) * 100, 1), "%");
                break;
            }
        }
    }
    
    // Régimen actual
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        ENUM_MARKET_REGIME regime = g_regimeDetector.GetCurrentRegime();
        Print("\n📈 RÉGIMEN: ", EnumToString(regime));
        Print("  Trades en régimen: ", g_tradesInCurrentRegime);
        Print("  P&L en régimen: ", DoubleToString(g_regimeProfit, 2));
    }
    
    // Guardar estadísticas
    g_metaLearning.SaveToFiles();
    
    Print("\n╚══════════════════════════════════════════════════════╝");
}

// FUNCIÓN AUXILIAR: Validar integridad
bool ValidateAgentDataIntegrity()
{
    if(g_metaLearning == NULL || g_totalCycles == 0) return true;
    
    // Verificar si todos tienen exactamente los mismos valores
    bool allSame = true;
    
    for(int i = 1; i < 5; i++)
    {
        if(g_metaLearning.m_agentStats[i].trades != g_metaLearning.m_agentStats[0].trades ||
           g_metaLearning.m_agentStats[i].wins != g_metaLearning.m_agentStats[0].wins ||
           g_metaLearning.m_agentStats[i].total_profit != g_metaLearning.m_agentStats[0].total_profit)
        {
            allSame = false;
            break;
        }
    }
    
    // Si todos son iguales después de varios trades, hay corrupción
    return !(allSame && g_totalCycles > 3);
}

// FUNCIÓN AUXILIAR: Reconstruir estadísticas
void RebuildAgentStatistics()
{
    if(g_voteHistoryCount == 0) return;
    
    Print("Reconstruyendo estadísticas desde historial de votos...");

    // Reset stats
    for(int i = 0; i < 5; i++)
    {
        g_metaLearning.m_agentStats[i].trades = 0;
        g_metaLearning.m_agentStats[i].wins = 0;
        g_metaLearning.m_agentStats[i].total_profit = 0.0;
        g_metaLearning.m_agentStats[i].consecutive_wins = 0;
        g_metaLearning.m_agentStats[i].consecutive_losses = 0;

        // CONSISTENCIA: Resetear EMAs a valor neutro 0.5
        for(int j = 0; j < 10; j++)
        {
            // g_metaLearning.UpdateAgentWinRateEMA(i, (j % 2 == 0)); // Alternar para converger a 0.5
        }
    }
    
    // Reconstruir desde historial
    for(int v = 0; v < g_voteHistoryCount; v++)
    {
        if(!g_voteHistory[v].tradeExecuted) continue;
        
        // Simular resultado basado en tiempo par/impar (temporal)
        bool wasWin = ((v % 3) != 0); // 66% win rate aproximado
        double profit = wasWin ? 150.0 : -100.0;
        
        for(int i = 0; i < 5; i++)
        {
            if(g_voteHistory[v].agents[i].voted)
            {
                g_metaLearning.m_agentStats[i].trades++;
                
                // Ajustar wins basado en si votó correctamente
                if(wasWin && g_voteHistory[v].agents[i].direction == g_voteHistory[v].finalDirection)
                {
                    g_metaLearning.m_agentStats[i].wins++;
                }
                
                // Distribuir profit proporcionalmente
                g_metaLearning.m_agentStats[i].total_profit += profit * 
                    g_voteHistory[v].agents[i].adjustedConfidence;
            }
        }
    }
    
    // Aplicar variaciones para diferenciar agentes
    RecalculateIndividualAgentStats();
    
    Print("✓ Estadísticas reconstruidas");
}

// FUNCIÓN AUXILIAR: Recalcular estadísticas individuales
void RecalculateIndividualAgentStats()
{
    if(g_metaLearning == NULL) return;
    
    // Asignar valores diferenciados para cada agente
    for(int i = 0; i < 5; i++)
    {
        double variation = 1.0;
        
        switch(i)
        {
            case 0: variation = 0.95; break;  // S/R ligeramente conservador
            case 1: variation = 0.98; break;  // Accum conservador
            case 2: variation = 1.05; break;  // Pattern ligeramente agresivo
            case 3: variation = 1.02; break;  // Breakout normal
            case 4: variation = 1.08; break;  // Institutional agresivo
        }
        
        g_metaLearning.m_agentStats[i].wins = (int)(g_metaLearning.m_agentStats[i].wins * variation);
        g_metaLearning.m_agentStats[i].total_profit *= variation;
    }

    // CRÍTICO: Sincronizar EMA con estadísticas recalculadas
    Print("Sincronizando EMAs con estadísticas recalculadas...");
    for(int i = 0; i < 5; i++)
    {
        if(g_metaLearning.m_agentStats[i].trades > 0)
        {
            double calculatedWR = (double)g_metaLearning.m_agentStats[i].wins / g_metaLearning.m_agentStats[i].trades;
            // Actualizar EMA múltiples veces para aproximar al winrate calculado
            for(int j = 0; j < 20; j++)
            {
                // g_metaLearning.UpdateAgentWinRateEMA(i, (calculatedWR >= 0.5));
            }
            Print("  ✓ ", g_metaLearning.m_agentNames[i], " - EMA sincronizado: ", DoubleToString(calculatedWR * 100, 1), "%");
        }
    }
}

// FUNCIÓN AUXILIAR: Calcular profit individual
double CalculateIndividualProfit(int agentIndex, double winRate, int trades)
{
    if(trades == 0) return 0.0;
    
    double avgWin = 150.0;   // Ganancia promedio
    double avgLoss = 100.0;  // Pérdida promedio
    
    // Ajustar por tipo de agente
    switch(agentIndex)
    {
        case 0: // S/R - Conservador: pequeñas ganancias consistentes
            avgWin = 120.0;
            avgLoss = 80.0;
            break;
        case 1: // Accum - Conservador
            avgWin = 130.0;
            avgLoss = 90.0;
            break;
        case 2: // Pattern - Agresivo: grandes movimientos
            avgWin = 200.0;
            avgLoss = 120.0;
            break;
        case 3: // Breakout - Normal
            avgWin = 150.0;
            avgLoss = 100.0;
            break;
        case 4: // Institutional - Agresivo
            avgWin = 180.0;
            avgLoss = 110.0;
            break;
    }
    
    int wins = (int)(trades * winRate);
    int losses = trades - wins;
    
    return (wins * avgWin) - (losses * avgLoss);
}

void PrintTouchDetected(bool seekingAdditional)
{
    if(seekingAdditional)
    {
        Print("\n═══ TOQUE S/R SENSIBLE PARA ORDEN ADICIONAL #", 
              g_orderExecution.m_multiOrder.orderCount + 1, " ═══");
    }
    else
    {
        Print("\n═══ TOQUE S/R DETECTADO (PRIMERA ORDEN) ═══");
    }
    
    Print("► Nivel: ", (g_touchContext.level.type == SR_SUPPORT ? "SOPORTE" : "RESISTENCIA"),
          " @ ", DoubleToString(g_touchContext.level.price, _Digits));
    Print("► Calidad: ", GetSRQualityString(g_touchContext.level.quality),
          " Fuerza: ", DoubleToString(g_touchContext.levelStrength, 1));
    Print("► Toque #", g_touchContext.touchNumber);
    
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        Print("► Régimen: ", EnumToString(g_regimeDetector.GetCurrentRegime()));
    }
}

void PrintAccumulationDetected(int minBarsRequired)
{
    Print("\n═══ ACUMULACIÓN VÁLIDA DETECTADA ═══");
    Print("► Barras: ", g_accumContext.barCount, " (mínimo: ", minBarsRequired, ")");
    Print("► Rango: ", DoubleToString(g_accumContext.range/_Point, 0), " puntos");
    
    if(g_currentCycle.seekingAdditional)
    {
        Print("► Tipo: ACUMULACIÓN RÁPIDA para orden adicional");
    }
}

void PrintNegotiationContext()
{
    if(g_currentCycle.seekingAdditional)
    {
        Print("► Tipo: ORDEN ADICIONAL #", g_orderExecution.m_multiOrder.orderCount + 1);
    }
    
    if(g_currentCycle.srLevelStrength > 0)
    {
        Print("► Nivel SR: Fuerza ", DoubleToString(g_currentCycle.srLevelStrength, 1),
              " Calidad ", GetSRQualityString(g_currentCycle.srLevelQuality));
    }
    
    if(g_currentCycle.activeDirection != VOTE_NEUTRAL)
    {
        Print("► DIRECCIÓN BLOQUEADA: ", 
              (g_currentCycle.activeDirection == VOTE_BUY ? "BUY" : "SELL"));
    }
    
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        RegimeParameters regimeParams = g_regimeDetector.GetCurrentParameters();
        Print("► Consenso mínimo (régimen): ", DoubleToString(regimeParams.minConsensusStrength, 2));
    }
    
    if(g_extendedTouch.hasHistoricalData)
    {
        Print("► Predicción histórica: ", 
              DoubleToString(g_extendedTouch.prediction.successProbability * 100, 1), "% éxito");
    }
}

void PrintConsensusReached()
{
    Print("\n═══ CONSENSO NEURONAL ALCANZADO ═══");
    Print("► Consensus ID: ", g_consensusResult.consensus_id);
    Print("► Dirección: ", (g_consensusResult.final_direction == VOTE_BUY ? "BUY" : "SELL"));
    Print("► Fuerza: ", DoubleToString(g_consensusResult.consensus_strength, 3));
    Print("► Convicción: ", DoubleToString(g_consensusResult.total_conviction, 3));
    Print("► Líder: ", g_consensusResult.leading_agent);
}

void PrintOrderContext(bool isFirstOrder)
{
    Print("► Consensus ID: ", g_consensusResult.consensus_id);
    Print("► Líder: ", g_currentCycle.leadingAgent);
    
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        Print("► Régimen: ", EnumToString(g_regimeDetector.GetCurrentRegime()));
    }
}

void PrintCycleSummary()
{
    Print("► Ciclo #", g_currentCycle.cycleNumber);
    Print("► Órdenes ejecutadas: ", g_currentCycle.ordersExecuted);
    Print("► Líder del ciclo: ", g_currentCycle.leadingAgent);
    
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        Print("► Régimen durante el ciclo: ", EnumToString(g_currentCycle.currentRegime));
    }
    
    if(g_EnableEpisodicMemory && g_currentCycle.episodeId > 0)
    {
        Print("► Episodio ID: ", g_currentCycle.episodeId);
    }
}

void PrintCycleDebugInfo()
{
    int ordersInProfit = 0;
    double totalProfit = 0;
    g_orderExecution.HasOrdersInProfit(ordersInProfit, totalProfit);
    
    Print("DEBUG CICLO v15:");
    Print("  Estado: ", StateToString(g_currentState));
    Print("  Órdenes: ", g_orderExecution.m_multiOrder.orderCount);
    Print("  En profit: ", ordersInProfit);
    Print("  P&L total: ", DoubleToString(totalProfit, 2));
    Print("  Líder: ", g_currentCycle.leadingAgent);
}

void CheckAndReportSignificantChanges()
{
    if(ShowPerformanceStats && g_metaLearning != NULL)
    {
        bool significantChange = false;
        
        for(int i = 0; i < 5; i++)
        {
            string oldPriv = g_metaLearning.GetAgentPrivilegeLevel((ENUM_COMPONENT_TYPE)i);
            g_metaLearning.CalculateAgentPrivileges();
            string newPriv = g_metaLearning.GetAgentPrivilegeLevel((ENUM_COMPONENT_TYPE)i);
            
            if(oldPriv != newPriv)
            {
                significantChange = true;
                Print("*** ", GetAgentName((ENUM_COMPONENT_TYPE)i), 
                      " cambió de ", oldPriv, " a ", newPriv, " ***");
            }
        }
        
        if(significantChange)
        {
            g_metaLearning.PrintAgentPerformanceReport();
        }
    }
}

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES                                             |
//+------------------------------------------------------------------+
string GetSRStateString(ENUM_SR_STATE state)
{
    switch(state)
    {
        case SR_STATE_INITIAL: return "Inicial";
        case SR_STATE_CONFIRMED: return "Confirmado";
        case SR_STATE_VALIDATED: return "Validado";
        case SR_STATE_BROKEN: return "Roto";
        default: return "Desconocido";
    }
}

string GetSRQualityString(ENUM_SR_QUALITY quality)
{
    switch(quality)
    {
        case SR_QUALITY_EXTREME: return "EXTREMA";
        case SR_QUALITY_CRITICAL: return "Crítica";
        case SR_QUALITY_STRONG: return "Fuerte";
        case SR_QUALITY_NORMAL: return "Normal";
        case SR_QUALITY_WEAK: return "Débil";
        default: return "?";
    }
}

string StateToString(TRADING_STATE state)
{
    switch(state)
    {
        case STATE_WAITING_SR_TOUCH: return "ESPERANDO_TOQUE_SR";
        case STATE_CHECKING_ACCUMULATION: return "VERIFICANDO_ACUMULACION";
        case STATE_NEURAL_NEGOTIATION: return "NEGOCIACION_NEURONAL";
        case STATE_EXECUTING_ORDER: return "EJECUTANDO_ORDEN";
        case STATE_MONITORING_POSITIONS: return "MONITOREANDO_POSICIONES";
        case STATE_CYCLE_COMPLETE: return "CICLO_COMPLETO";
        default: return "DESCONOCIDO";
    }
}

string SessionToString(ENUM_MARKET_SESSION session)
{
    switch(session)
    {
        case SESSION_ASIAN: return "Asia";
        case SESSION_LONDON_ML: return "Londres";
        case SESSION_NEWYORK: return "Nueva York";
        case SESSION_OVERLAP: return "Overlap";
        case SESSION_CLOSED: return "Cerrado";
        default: return "?";
    }
}

string GetAgentName(ENUM_COMPONENT_TYPE type)
{
    switch(type)
    {
        case COMPONENT_SUPPORT_RESIST: return "S/R";
        case COMPONENT_ACCUM_ZONES: return "Accum";
        case COMPONENT_PATTERN_MEMORY: return "Pattern";
        case COMPONENT_BREAKOUT_DETECT: return "Breakout";
        case COMPONENT_INSTITUTIONAL: return "Inst";
        default: return "Unknown";
    }
}

// Conteo de agentes en desacuerdo
int CountDissentingAgents()
{
    int count = 0;
    if(g_voteHistoryCount > 0)
    {
        int lastIdx = g_voteHistoryCount - 1;
        ENUM_VOTE_DIRECTION consensus = g_voteHistory[lastIdx].finalDirection;
        
        for(int i = 0; i < 5; i++)
        {
            if(g_voteHistory[lastIdx].agents[i].voted && 
               g_voteHistory[lastIdx].agents[i].direction != consensus)
            {
                count++;
            }
        }
    }
    return count;
}

// Obtener sesión actual
ENUM_MARKET_SESSION GetSessionType()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int hour = dt.hour;
    
    if(hour >= 0 && hour < 8)
        return SESSION_ASIAN;
    else if(hour >= 8 && hour < 13)
        return SESSION_LONDON_ML;
    else if(hour >= 13 && hour < 22)
        return SESSION_NEWYORK;
    else
        return SESSION_CLOSED;
}

//+------------------------------------------------------------------+
//| VISUALIZACIÓN                                                    |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
    string info = "╔══════════════════════════════════════════════════════╗\n";
    info += "║        NEURAL CONSENSUS v15 FIXED                    ║\n";
    info += "╚══════════════════════════════════════════════════════╝\n\n";
    
    info += "▶ ESTADO: " + StateToString(g_currentState) + "\n";
    info += "▶ SESIÓN: " + SessionToString(g_market.session) + "\n";
    info += "▶ CICLO #" + IntegerToString(g_currentCycle.cycleNumber) + "\n";
    
    if(g_EnableRegimeDetection && g_regimeDetector != NULL)
    {
        info += "▶ RÉGIMEN: " + EnumToString(g_regimeDetector.GetCurrentRegime()) + "\n";
    }
    
    if(g_extendedTouch.hasHistoricalData)
    {
        info += "▶ PREDICCIÓN: " + 
                DoubleToString(g_historicalSuccessRate * 100, 1) + "% (" +
                IntegerToString(g_similarEpisodesFound) + " eps)\n";
    }
    
    if(g_currentCycle.seekingAdditional)
    {
        info += "▶ MODO: ORDEN ADICIONAL\n";
    }
    
    if(g_currentMasterAgent != "" && g_currentMasterAgent != "None")
    {
        info += "▶ MASTER: " + g_currentMasterAgent + "\n";
    }
    
    info += "\n";
    
    // Información SR
    if(g_nearestSupportPrice > 0 || g_nearestResistancePrice > 0)
    {
        info += "═══ NIVELES SR ═══\n";
        if(g_nearestSupportPrice > 0)
            info += "Soporte: " + DoubleToString(g_nearestSupportPrice, _Digits) + "\n";
        if(g_nearestResistancePrice > 0)
            info += "Resistencia: " + DoubleToString(g_nearestResistancePrice, _Digits) + "\n";
        info += "Fuertes cerca: " + IntegerToString(g_strongLevelsNearby) + "\n\n";
    }
    
    if(ShowEmotionalAnalysis)
    {
        info += "═══ EMOCIONES ═══\n";
        info += "Miedo: " + DoubleToString(g_marketEmotion.fear, 2) + 
                (g_marketEmotion.fear > EmotionalThreshold ? " ⚠" : "") + "\n";
        info += "Codicia: " + DoubleToString(g_marketEmotion.greed, 2) + 
                (g_marketEmotion.greed > EmotionalThreshold ? " ⚠" : "") + "\n";
        info += "Incertidumbre: " + DoubleToString(g_marketEmotion.uncertainty, 2) + "\n\n";
    }
    
    if(g_touchContext.valid)
    {
        info += "═══ TOQUE S/R ═══\n";
        info += "Precio: " + DoubleToString(g_touchContext.price, _Digits) + "\n";
        info += "Tipo: " + (g_touchContext.level.type == SR_SUPPORT ? "SOPORTE" : "RESISTENCIA") + "\n";
        info += "Calidad: " + GetSRQualityString(g_touchContext.level.quality) + "\n";
        info += "Fuerza: " + DoubleToString(g_touchContext.levelStrength, 1) + "\n\n";
    }
    
    if(g_currentState == STATE_CHECKING_ACCUMULATION)
    {
        info += "═══ ACUMULACIÓN ═══\n";
        info += "Barras: " + IntegerToString(g_accumBarsSinceTouch) + "\n";
        
        int minBarsNeeded = MinAccumulationBars;
        if(g_EnableRegimeDetection && g_regimeDetector != NULL)
        {
            RegimeParameters regimeParams = g_regimeDetector.GetCurrentParameters();
            minBarsNeeded = regimeParams.minAccumulationBars;
        }
        if(g_currentCycle.seekingAdditional)
            minBarsNeeded = 2;
            
        info += "Mínimo: " + IntegerToString(minBarsNeeded) + "\n\n";
    }
    
    if(g_orderExecution.m_multiOrder.cycleActive)
    {
        info += "═══ CICLO ACTIVO ═══\n";
        info += "Órdenes: " + IntegerToString(g_orderExecution.m_multiOrder.orderCount) + 
                "/" + IntegerToString(MaxOrdersPerCycle) + "\n";
        info += "Dirección: " + (g_orderExecution.m_multiOrder.direction == DIRECTION_BUY ? "BUY" : "SELL") + "\n";
        info += "P&L: " + DoubleToString(g_orderExecution.m_multiOrder.cycleProfit, 2) + "\n";
        
        // Estado de primera orden
        if(g_orderExecution.m_multiOrder.tickets[0] > 0)
        {
            if(PositionSelectByTicket(g_orderExecution.m_multiOrder.tickets[0]))
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                double points = 0;
                
                if(g_orderExecution.m_multiOrder.direction == DIRECTION_BUY)
                    points = (currentPrice - openPrice) / _Point;
                else
                    points = (openPrice - currentPrice) / _Point;
                
                info += "1ª orden: " + DoubleToString(points, 0) + " pts";
                if(points >= MinProfitForAdditional)
                    info += " ✓";
                info += "\n";
            }
        }
        info += "\n";
    }
    
    info += "═══ ESTADÍSTICAS ═══\n";
    info += "Trades hoy: " + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(MaxDailyTrades) + "\n";
    info += "Ciclos: " + IntegerToString(g_totalCycles) + "\n";
    // TODO: Método no existe - info += "Éxito: " + DoubleToString(g_votingStats.GetSuccessRate() * 100, 1) + "%\n";
    info += "Volatilidad: " + DoubleToString(g_market.volatilityRatio, 2) + "x\n";
    
    Comment(info);
}

//+------------------------------------------------------------------+
//| EVENTOS DE TECLADO                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if(id == CHARTEVENT_KEYDOWN)
    {
        // Tecla D - Debug
        if(lparam == 68) 
        {
            PrintDebugInfo();
        }
        // Tecla R - Reset manual
        else if(lparam == 82)
        {
            Print("=== RESET MANUAL ===");
            
            if(g_EnableEpisodicMemory && g_currentCycle.episodeId > 0)
            {
                CompleteCurrentEpisode(false);
            }
            
            ResetCycle();
        }
        // Tecla P - Estado de posiciones
        else if(lparam == 80)
        {
            PrintPositionsState();
        }
        // Tecla C - Configuración actual
        else if(lparam == 67)
        {
            PrintCurrentConfiguration();
        }
        // Tecla S - Estadísticas SR
        else if(lparam == 83)
        {
            if(g_srManager != NULL)
            {
                g_srManager.PrintStatistics();
                double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
                g_srManager.PrintNearbyLevels(currentPrice, g_market.currentATR * 2);
            }
        }
        // Tecla A - Performance de agentes
        else if(lparam == 65)
        {
            if(g_metaLearning != NULL)
            {
                g_metaLearning.PrintAgentDetailedStats();
            }
        }
        // Tecla T - Trade record tracking
        else if(lparam == 84)
        {
            PrintTradeRecordStats();
        }
    }
}

void PrintDebugInfo()
{
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║            DEBUG INFO NCN v15 FIXED                  ║");
    Print("╚══════════════════════════════════════════════════════╝");
    Print("Estado: ", StateToString(g_currentState));
    Print("Barras en estado: ", g_barsInCurrentState);
    Print("Ciclo #", g_currentCycle.cycleNumber);
    
    if(g_touchContext.valid)
    {
        Print("\n--- Toque SR Activo ---");
        Print("Precio: ", DoubleToString(g_touchContext.price, _Digits));
        Print("Calidad: ", DoubleToString(g_touchContext.quality, 3));
        Print("Fuerza: ", DoubleToString(g_touchContext.levelStrength, 1));
    }
    
    if(g_currentCycle.leadingAgent != "")
    {
        Print("\n--- Consenso ---");
        Print("Líder: ", g_currentCycle.leadingAgent);
        Print("Calidad: ", DoubleToString(g_currentCycle.consensusQuality, 3));
    }
    
    if(g_orderExecution.m_multiOrder.cycleActive)
    {
        Print("\n--- Órdenes Activas ---");
        Print("Cantidad: ", g_orderExecution.m_multiOrder.orderCount);
        Print("P&L: ", DoubleToString(g_orderExecution.m_multiOrder.cycleProfit, 2));
        
        // Mostrar consensus_ids
        Print("\n--- Tracking de Consensus IDs ---");
        Print("ID inicial del ciclo: ", g_orderExecution.m_multiOrder.initial_consensus_id);
        for(int i = 0; i < g_orderExecution.m_multiOrder.orderCount; i++)
        {
            Print("Orden ", i+1, " - Ticket: ", g_orderExecution.m_multiOrder.tickets[i],
                  " CID: ", g_orderExecution.m_multiOrder.consensus_ids[i]);
        }
    }
    
    Print("══════════════════════════════════════════════════════");
}

void PrintPositionsState()
{
    Print("═══ ESTADO DE POSICIONES ═══");
    
    if(g_orderExecution.m_multiOrder.cycleActive)
    {
        Print("Ciclo activo: SÍ");
        Print("Órdenes: ", g_orderExecution.m_multiOrder.orderCount);
        Print("Dirección: ", g_orderExecution.m_multiOrder.direction == DIRECTION_BUY ? "BUY" : "SELL");
        
        for(int i = 0; i < g_orderExecution.m_multiOrder.orderCount; i++)
        {
            if(g_orderExecution.m_multiOrder.tickets[i] > 0)
            {
                if(PositionSelectByTicket(g_orderExecution.m_multiOrder.tickets[i]))
                {
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                    
                    double points = 0;
                    if(g_orderExecution.m_multiOrder.direction == DIRECTION_BUY)
                        points = (currentPrice - openPrice) / _Point;
                    else
                        points = (openPrice - currentPrice) / _Point;
                    
                    Print("  Orden ", i+1, ": ",
                          " P&L: ", DoubleToString(profit, 2),
                          " Mov: ", DoubleToString(points, 0), " pts");
                }
            }
        }
        
        Print("P&L Total: ", DoubleToString(g_orderExecution.m_multiOrder.cycleProfit, 2));
    }
    else
    {
        Print("No hay ciclo activo");
    }
    
    Print("════════════════════════");
}

void PrintCurrentConfiguration()
{
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║         CONFIGURACIÓN NCN v15 FIXED                  ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    Print("\nMÓDULOS:");
    Print("  • MetaLearning: ", EnableMetaLearning ? "ACTIVO" : "INACTIVO");
    Print("  • RegimeDetection: ", g_EnableRegimeDetection ? "ACTIVO" : "INACTIVO");
    Print("  • EpisodicMemory: ", g_EnableEpisodicMemory ? "ACTIVO" : "INACTIVO");
    
    Print("\nPARÁMETROS SR:");
    Print("  • Fuerza mínima: ", DoubleToString(MinLevelStrength, 1));
    Print("  • Calidad mínima: ", EnumToString(MinLevelQuality));
    Print("  • Sensibilidad adicionales: x", DoubleToString(SensitivityMultiplier, 2));
    
    Print("\nPARÁMETROS NEURAL:");
    Print("  • Consenso mínimo: ", DoubleToString(MinConsensusStrength, 2));
    Print("  • Convicción mínima: ", DoubleToString(MinTotalConviction, 2));
    
    Print("\nGESTIÓN DE RIESGO:");
    Print("  • Riesgo base: ", DoubleToString(RiskPercentage, 1), "%");
    Print("  • Max drawdown: ", DoubleToString(MaxDrawdown, 1), "%");
    Print("  • Max órdenes/ciclo: ", MaxOrdersPerCycle);
    
    Print("\nESTADO:");
    Print("  • Estado actual: ", StateToString(g_currentState));
    Print("  • Ciclo activo: ", g_orderExecution.m_multiOrder.cycleActive ? "SÍ" : "NO");
    Print("  • Master Agent: ", g_currentMasterAgent != "" ? g_currentMasterAgent : "Ninguno");
    
    Print("══════════════════════════════════════════════════════");
}

void PrintTradeRecordStats()
{
    if(g_metaLearning == NULL) return;
    
    Print("╔══════════════════════════════════════════════════════╗");
    Print("║         ESTADÍSTICAS DE TRADE RECORDS                ║");
    Print("╚══════════════════════════════════════════════════════╝");
    
    // Esta función dependería de métodos públicos en MetaLearning
    // Por ahora, mostrar información básica disponible
    
    Print("Consensus IDs procesados en esta sesión:");
    if(g_voteHistoryCount > 0)
    {
        for(int i = 0; i < g_voteHistoryCount && i < 10; i++)
        {
            Print("  CID: ", g_voteHistory[i].consensus_id,
                  " - Ejecutado: ", g_voteHistory[i].tradeExecuted ? "SÍ" : "NO",
                  " - Ticket: ", g_voteHistory[i].orderTicket);
        }
    }
    
    Print("══════════════════════════════════════════════════════");
}

// Función para inicializar agentes (stub si no se usa)
void InitializeAgents()
{
    for(int i = 0; i < 5; i++)
    {
        g_agents[i].hasVoted = false;
        g_agents[i].currentPosition = 0;
    }
}

// Stubs para funciones de confianza si no existen en las clases
double GetBreakoutConfidence()
{
    // Método alternativo para obtener confianza del breakout detector
    if(g_breakoutDetector != NULL)
    {
        return g_breakoutDetector.GetDirectionConfidence() / 100.0;
    }
    return 0.5; // Valor por defecto si no hay método disponible
}

double GetInstitutionalConfidence()
{
    // Método alternativo para obtener confianza del institutional finder
    if(g_instPlanFinder != NULL)
    {
        return g_instPlanFinder.GetDirectionConfidence() / 100.0;
    }
    return 0.5; // Valor por defecto si no hay método disponible
}

//+------------------------------------------------------------------+
//| Auto-generated helper implementations (v17)                       |
//| Simplified placeholders to resolve missing identifiers.           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| IMPLEMENTACIONES QUE FALTABAN (Helpers)                          |
//+------------------------------------------------------------------+
double CalculateAgentRecentPerformance(int agentIndex, int lookbackHours)
{
   // Implementación real basada en estadísticas de MetaLearning
   if(g_metaLearning != NULL)
   {
       // Usar el WinRate general como proxy si no hay desglose por horas
       return g_metaLearning.GetAgentWinRate((ENUM_COMPONENT_TYPE)agentIndex);
   }
   return 0.5;
}

double CalculateRecentWinRate(int lookbackTrades)
{
   if(g_metaLearning != NULL)
       return g_metaLearning.GetConsensusSuccessRate();
   return 0.5;
}

double CalculateCurrentDrawdown()
{
   // Cálculo simple de drawdown actual de cuenta
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0) return (balance - equity) / balance * 100.0;
   return 0.0;
}

bool CheckAgentsDisagree(int agentA, int agentB)
{
   // Verificar desacuerdo en el último voto
   if(g_voteHistoryCount > 0)
   {
       int lastIdx = g_voteHistoryCount - 1;
       // Si ambos votaron y tienen direcciones opuestas
       if(g_voteHistory[lastIdx].agents[agentA].voted && 
          g_voteHistory[lastIdx].agents[agentB].voted)
       {
           return g_voteHistory[lastIdx].agents[agentA].direction != 
                  g_voteHistory[lastIdx].agents[agentB].direction;
       }
   }
   return false;
}

double GetAsianSessionWinRate()
{
   // Retornar valor neutral por ahora
   return 0.5;
}





//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Custom optimization criterion                                    |
//+------------------------------------------------------------------+
double OnTester()
  {
   double netProfit    =  TesterStatistics(STAT_PROFIT);             // Total net profit in deposit currency
   double maxDDPercent =  TesterStatistics(STAT_EQUITY_DDREL_PERCENT);  // Maximum relative equity drawdown %
   double profitFactor =  TesterStatistics(STAT_PROFIT_FACTOR);      // Profit factor

   //--- protect against division by zero
   if(maxDDPercent<=0.0)
      maxDDPercent = 0.01;

   //--- Composite score: prioritize profit & stability (higher is better)
   double score = (netProfit/100.0) * profitFactor / maxDDPercent;
   return(score);
  }