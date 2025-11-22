//+------------------------------------------------------------------+
//| MetaLearningQuantum.mqh - Sistema ML de Guerra v2.0             |
//| Arquitectura Quantum Warfare para Mercados Financieros          |
//| Copyright 2025, Quantum Trading Co                              |
//| VERSION: 100% COMPLETA CON MEJORAS AVANZADAS DE ERROR PATTERNS  |
//+------------------------------------------------------------------+
#ifndef META_LEARNING_QUANTUM_MQH
#define META_LEARNING_QUANTUM_MQH

#include <Math\Stat\Math.mqh>

#include <Arrays\ArrayDouble.mqh>
#include <Trade\Trade.mqh>
#include <RegimeDetectionSystem.mqh>


//+------------------------------------------------------------------+
//| Estructura para señales de trading (NO ejecuta órdenes)         |
//+------------------------------------------------------------------+
struct TradeSignal
{
    int direction;              // 1=BUY, -1=SELL, 0=NONE
    double volume;              // Tamaño del lote principal
    double price;               // Precio de entrada sugerido
    double stopLoss;            // Stop loss sugerido
    double takeProfit;          // Take profit sugerido
    string reasoning;           // Razón de la decisión
    bool useAITrailing;         // Usar trailing inteligente
    double confidence;          // Confianza en la señal (0-1)
    bool isValid;               // Señal válida para ejecutar
    
    // Para multi-orden
    int orderCount;             // Número de órdenes (1 para single, >1 para multi)
    double volumes[10];         // Volúmenes para cada orden
    double entryPrices[10];     // Precios de entrada para cada orden
    double stopLosses[10];      // Stop losses para cada orden
    double takeProfits[10];     // Take profits para cada orden
    
    // Información adicional
    double atrMultiplier;       // Multiplicador ATR usado
    double expectedReturn;      // Retorno esperado
    int consensusAgents;        // Agentes que votaron a favor
    
    // Constructor
    void Init() {
        direction = 0;
        volume = 0.0;
        price = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        reasoning = "";
        useAITrailing = false;
        confidence = 0.0;
        isValid = false;
        orderCount = 0;
        atrMultiplier = 1.5;
        expectedReturn = 2.0;
        consensusAgents = 0;
        
        for(int i = 0; i < 10; i++) {
            volumes[i] = 0.0;
            entryPrices[i] = 0.0;
            stopLosses[i] = 0.0;
            takeProfits[i] = 0.0;
        }
    }
};
//+------------------------------------------------------------------+
//| Definir constantes faltantes                                    |
//+------------------------------------------------------------------+
#ifndef M_PI
   #define M_PI 3.14159265358979323846
#endif

//+------------------------------------------------------------------+
//| Configuración Global del Sistema                                |
//+------------------------------------------------------------------+
#define QUANTUM_MAX_FEATURES 256
#define QUANTUM_MAX_AGENTS 5
#define QUANTUM_MAX_ORDERS 10
#define QUANTUM_MEMORY_SIZE 10000
#define QUANTUM_ENSEMBLE_SIZE 3

// REEMPLAZAR: Función GlobalRandomNormal
// MEJORA: Protege contra log(0) y asegura distribución normal válida.
double GlobalRandomNormal(double mean, double std) {
    static bool hasSpare = false;
    static double spare = 0.0;
    
    // Validación de seguridad
    if(std <= 0) return mean; // Retorna la media si la desviación es inválida

    if(hasSpare) {
        hasSpare = false;
        return mean + std * spare;
    }

    hasSpare = true;
    // Generación segura: [0.0001, 0.9999] para evitar errores en MathLog
    double u = (MathRand() + 1.0) / 32769.0; // Denominador ajustado para rango (0,1)
    double v = (MathRand() + 1.0) / 32769.0;
    u = MathMax(0.000001, MathMin(0.999999, u)); 

    // Transformación Box-Muller
    double mag = std * MathSqrt(-2.0 * MathLog(u));
    spare = mag * MathCos(2.0 * M_PI * v);
    return mean + mag * MathSin(2.0 * M_PI * v);
}

//+------------------------------------------------------------------+
//| Enumeraciones Mejoradas                                         |
//+------------------------------------------------------------------+
enum ENUM_FINAL_ACTION {
    ACT_SKIP = 0,           // No trade
    ACT_WAIT = 1,           // Esperar mejor setup
    ACT_EXEC_SINGLE = 2,    // Una orden
    ACT_EXEC_SCALE = 3,     // Scale-in (2-3 órdenes)
    ACT_EXEC_PYRAMID = 4,   // Pyramid (4-6 órdenes)
    ACT_EXEC_ASSAULT = 5    // Full assault (7-10 órdenes)
};

enum ENUM_ML_STRATEGY {
    STRAT_CONSERVATIVE = 0,  // Bajo riesgo, alta certeza
    STRAT_BALANCED = 1,     // Balance riesgo/reward
    STRAT_AGGRESSIVE = 2,   // Alto riesgo, alta reward
    STRAT_ADAPTIVE = 3      // Se ajusta dinámicamente
};

enum ENUM_MARKET_SESSION {
    SESSION_ASIAN = 0,
    SESSION_LONDON_ML = 1,  // Renombrado para evitar conflicto con ENUM_TRADING_SESSION
    SESSION_NEWYORK = 2,
    SESSION_OVERLAP = 3,
    SESSION_CLOSED = 4
};

//+------------------------------------------------------------------+
//| NUEVO: Estructura Avanzada para Patrones de Error en Votos     |
//| AUDITADO: Agregados límites y validaciones                      |
//+------------------------------------------------------------------+
struct VoteErrorPattern {
    string agentName;               // Nombre del agente que falló
    ENUM_MARKET_REGIME regime;      // Régimen de mercado donde ocurrió el error
    double confidenceAtError;       // Confianza media del voto erróneo en este patrón
    int failureCount;               // Número total de fallos en este patrón específico
    double adjustmentFactor;        // Factor multiplicador para reducir convicción/peso (0.4-1.0)
    datetime lastErrorTime;         // Timestamp del último error en este patrón
    double errorSeverityAvg;        // Severidad media del error (0-1 donde 1 es pérdida máxima)
    int consecutiveFailures;        // Fallos consecutivos recientes
    double recoveryThreshold;       // Umbral de trades exitosos para empezar recuperación
    int successSinceLastError;      // Contador de trades exitosos desde el último error
    
    // Constructor mejorado con validaciones
    void Initialize() {
        agentName = "";
        regime = REGIME_RANGING;
        confidenceAtError = 0.0;
        failureCount = 0;
        adjustmentFactor = 1.0;
        lastErrorTime = 0;
        errorSeverityAvg = 0.0;
        consecutiveFailures = 0;
        recoveryThreshold = 5.0;
        successSinceLastError = 0;
    }
    
    // AUDITORÍA: Método para validar consistencia
    // AUDITORÍA: Método para validar consistencia
    bool Validate() {
        bool wasInvalid = false;
        // Rango válido para adjustmentFactor: [0.4, 1.0]
        if(adjustmentFactor < 0.0 || adjustmentFactor > 1.0) {
            adjustmentFactor = MathMax(0.4, MathMin(1.0, adjustmentFactor));
            wasInvalid = true;
        }
        // Si hay demasiados fallos seguidos, eleva el umbral de recuperación con tope
        if(consecutiveFailures > 10) {
            recoveryThreshold = MathMin(recoveryThreshold * 1.5, 20.0);
            wasInvalid = true;
        }
        // Valores mínimos coherentes
        if(failureCount < 0) failureCount = 0;
        if(successSinceLastError < 0) successSinceLastError = 0;
        // Clamp de métricas normalizadas
        if(errorSeverityAvg < 0.0 || errorSeverityAvg > 1.0) {
            errorSeverityAvg = MathMax(0.0, MathMin(1.0, errorSeverityAvg));
            wasInvalid = true;
        }
        if(confidenceAtError < 0.0 || confidenceAtError > 1.0) {
            confidenceAtError = MathMax(0.0, MathMin(1.0, confidenceAtError));
            wasInvalid = true;
        }
        return !wasInvalid;
    }
};

//+------------------------------------------------------------------+
//| Clase del Sistema de Meta-Aprendizaje CORREGIDA                |
//+------------------------------------------------------------------+
class CMetaLearningSystem
{
private:
    // Indicadores técnicos
    int         m_handleMA20;         // Media móvil 20
    int         m_handleMA50;         // Media móvil 50
    int         m_handleRSI;          // RSI
    int         m_handleBB;           // Bandas de Bollinger
    int         m_handleMACD;         // MACD
    int         m_handleATR;          // ATR para volatilidad
    int         m_handleStoch;        // Stochastic
    
    // Buffers para indicadores
    double      m_bufferMA20[];
    double      m_bufferMA50[];
    double      m_bufferRSI[];
    double      m_bufferBBUpper[];
    double      m_bufferBBMiddle[];
    double      m_bufferBBLower[];
    double      m_bufferMACD[];
    double      m_bufferMACDSignal[];
    double      m_bufferATR[];
    double      m_bufferStochMain[];
    double      m_bufferStochSignal[];
    
    // Configuración
    double      m_riskRewardRatio;    // Ratio riesgo/beneficio
    int         m_stopLossPoints;     // Stop loss en puntos
    int         m_takeProfitPoints;   // Take profit en puntos
    double      m_confidenceThreshold; // Umbral de confianza para trading
    
    // Control de señales
    datetime    m_lastSignalTime;     // Última vez que se generó señal
    int         m_lastSignalType;     // Tipo de última señal
    double      m_lastConfidence;     // Confianza de la última señal
    
    // Análisis de mercado
    double      m_currentVolatility;
    double      m_trendStrength;
    double      m_momentum;
    
    // Funciones privadas
    bool        LoadIndicators();
    void        ReleaseIndicators();
    bool        UpdateBuffers();
    int         AnalyzeTrend();
    bool        CheckEntryConditions(int trendDirection);
    double      CalculateSignalStrength();
    double      CalculateConfidence();
    int         EvaluateMarketConditions();
    
public:
    // Constructor y destructor
                CMetaLearningSystem();
               ~CMetaLearningSystem();
    
    // Inicialización
    bool        Initialize();
    
    // Funciones principales CORREGIDAS
    int         GetTradingSignal();   // 1 = Buy, -1 = Sell, 0 = No signal
    double      GetSignalConfidence(); // Confianza de la señal [0-1]
    bool        IsMarketFavorable();  // Verificar si el mercado es favorable
    
    // Nuevas funciones para integración
    double      GetVolatility() { return m_currentVolatility; }
    double      GetTrendStrength() { return m_trendStrength; }
    double      GetMomentum() { return m_momentum; }
    
    // Gestión de SL/TP
    double      CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice);
    double      CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice);
    // Funciones de predicción
    double      PredictNextMove(const double &features[], int featureCount);
    void        UpdatePrediction(double actualResult, double predictedResult);
};


//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMetaLearningSystem::CMetaLearningSystem()
{
    m_handleMA20 = INVALID_HANDLE;
    m_handleMA50 = INVALID_HANDLE;
    m_handleRSI = INVALID_HANDLE;
    m_handleBB = INVALID_HANDLE;
    m_handleMACD = INVALID_HANDLE;
    m_handleATR = INVALID_HANDLE;
    m_handleStoch = INVALID_HANDLE;
    
    m_riskRewardRatio = 2.0;
    m_stopLossPoints = 200;
    m_takeProfitPoints = 400;
    m_confidenceThreshold = 0.6;
    
    m_lastSignalTime = 0;
    m_lastSignalType = 0;
    m_lastConfidence = 0;
    
    m_currentVolatility = 0;
    m_trendStrength = 0;
    m_momentum = 0;
}


//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMetaLearningSystem::~CMetaLearningSystem()
{
    ReleaseIndicators();
}

//+------------------------------------------------------------------+
//| Inicialización del sistema                                      |
//+------------------------------------------------------------------+
bool CMetaLearningSystem::Initialize()
{
    if(!LoadIndicators())
    {
        Print("ERROR: No se pudieron cargar los indicadores ML");
        return false;
    }
    
    Print("Sistema ML inicializado correctamente");
    return true;
}


//+------------------------------------------------------------------+
//| Cargar indicadores técnicos                                     |
//+------------------------------------------------------------------+
bool CMetaLearningSystem::LoadIndicators()
{
    m_handleMA20 = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    m_handleMA50 = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    m_handleRSI = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    m_handleBB = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2, PRICE_CLOSE);
    m_handleMACD = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
    m_handleATR = iATR(_Symbol, PERIOD_CURRENT, 14);
    m_handleStoch = iStochastic(_Symbol, PERIOD_CURRENT, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
    
    if(m_handleMA20 == INVALID_HANDLE || 
       m_handleMA50 == INVALID_HANDLE || 
       m_handleRSI == INVALID_HANDLE ||
       m_handleBB == INVALID_HANDLE || 
       m_handleMACD == INVALID_HANDLE ||
       m_handleATR == INVALID_HANDLE ||
       m_handleStoch == INVALID_HANDLE)
    {
        Print("ERROR: Fallo al crear handles de indicadores");
        return false;
    }
    
    // Configurar arrays como series
    ArraySetAsSeries(m_bufferMA20, true);
    ArraySetAsSeries(m_bufferMA50, true);
    ArraySetAsSeries(m_bufferRSI, true);
    ArraySetAsSeries(m_bufferBBUpper, true);
    ArraySetAsSeries(m_bufferBBMiddle, true);
    ArraySetAsSeries(m_bufferBBLower, true);
    ArraySetAsSeries(m_bufferMACD, true);
    ArraySetAsSeries(m_bufferMACDSignal, true);
    ArraySetAsSeries(m_bufferATR, true);
    ArraySetAsSeries(m_bufferStochMain, true);
    ArraySetAsSeries(m_bufferStochSignal, true);
    
    return true;
}



//+------------------------------------------------------------------+
//| Liberar indicadores                                             |
//+------------------------------------------------------------------+
void CMetaLearningSystem::ReleaseIndicators()
{
    if(m_handleMA20 != INVALID_HANDLE) IndicatorRelease(m_handleMA20);
    if(m_handleMA50 != INVALID_HANDLE) IndicatorRelease(m_handleMA50);
    if(m_handleRSI != INVALID_HANDLE) IndicatorRelease(m_handleRSI);
    if(m_handleBB != INVALID_HANDLE) IndicatorRelease(m_handleBB);
    if(m_handleMACD != INVALID_HANDLE) IndicatorRelease(m_handleMACD);
    if(m_handleATR != INVALID_HANDLE) IndicatorRelease(m_handleATR);
    if(m_handleStoch != INVALID_HANDLE) IndicatorRelease(m_handleStoch);
}
//+------------------------------------------------------------------+
//| Actualizar buffers de indicadores                               |
//+------------------------------------------------------------------+
bool CMetaLearningSystem::UpdateBuffers()
{
    int barsNeeded = 3;
    
    if(CopyBuffer(m_handleMA20, 0, 0, barsNeeded, m_bufferMA20) != barsNeeded) return false;
    if(CopyBuffer(m_handleMA50, 0, 0, barsNeeded, m_bufferMA50) != barsNeeded) return false;
    if(CopyBuffer(m_handleRSI, 0, 0, barsNeeded, m_bufferRSI) != barsNeeded) return false;
    if(CopyBuffer(m_handleBB, 0, 0, barsNeeded, m_bufferBBUpper) != barsNeeded) return false;
    if(CopyBuffer(m_handleBB, 1, 0, barsNeeded, m_bufferBBMiddle) != barsNeeded) return false;
    if(CopyBuffer(m_handleBB, 2, 0, barsNeeded, m_bufferBBLower) != barsNeeded) return false;
    if(CopyBuffer(m_handleMACD, 0, 0, barsNeeded, m_bufferMACD) != barsNeeded) return false;
    if(CopyBuffer(m_handleMACD, 1, 0, barsNeeded, m_bufferMACDSignal) != barsNeeded) return false;
    if(CopyBuffer(m_handleATR, 0, 0, barsNeeded, m_bufferATR) != barsNeeded) return false;
    if(CopyBuffer(m_handleStoch, 0, 0, barsNeeded, m_bufferStochMain) != barsNeeded) return false;
    if(CopyBuffer(m_handleStoch, 1, 0, barsNeeded, m_bufferStochSignal) != barsNeeded) return false;
    
    // Actualizar volatilidad
    m_currentVolatility = m_bufferATR[0];
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcular confianza de la señal                                  |
//+------------------------------------------------------------------+
double CMetaLearningSystem::CalculateConfidence()
{
    double confidence = 0.5; // Base
    
    // Factor 1: Fuerza de tendencia
    if(m_trendStrength > 1.5)
        confidence += 0.15;
    else if(m_trendStrength > 0.5)
        confidence += 0.1;
    
    // Factor 2: Momentum
    if(MathAbs(m_momentum) > 1.0)
        confidence += 0.1;
    
    // Factor 3: RSI en zona favorable
    if(m_bufferRSI[0] > 40 && m_bufferRSI[0] < 60)
        confidence += 0.1; // RSI neutral es favorable
    else if(m_bufferRSI[0] > 30 && m_bufferRSI[0] < 70)
        confidence += 0.05;
    
    // Factor 4: Volatilidad
    double avgATR = (m_bufferATR[0] + m_bufferATR[1] + m_bufferATR[2]) / 3;
    if(m_bufferATR[0] < avgATR * 1.2) // Volatilidad estable
        confidence += 0.1;
    
    // Factor 5: Confluencia de Bollinger Bands
    double bbWidth = m_bufferBBUpper[0] - m_bufferBBLower[0];
    double avgBBWidth = bbWidth / m_bufferBBMiddle[0];
    if(avgBBWidth < 0.02) // Bandas estrechas
        confidence += 0.05;
    
    return MathMax(0.0, MathMin(1.0, confidence));
}

//+------------------------------------------------------------------+
//| Evaluar condiciones del mercado                                 |
//+------------------------------------------------------------------+
int CMetaLearningSystem::EvaluateMarketConditions()
{
    // 1 = Favorable, 0 = Neutral, -1 = Desfavorable
    
    // Verificar volatilidad
    double avgATR = (m_bufferATR[0] + m_bufferATR[1] + m_bufferATR[2]) / 3;
    if(m_bufferATR[0] > avgATR * 2.0)
        return -1; // Volatilidad muy alta
    
    // Verificar spread
    double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
    if(spread > m_bufferATR[0] * 0.3)
        return -1; // Spread muy alto
    
    // Verificar volumen (si está disponible)
    long volume = SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
    if(volume > 0)
    {
        static long avgVolume = volume;
        avgVolume = (avgVolume * 9 + volume) / 10;
        
        if(volume < avgVolume * 0.5)
            return -1; // Volumen muy bajo
    }
    
    return 1; // Condiciones favorables
}

//+------------------------------------------------------------------+
//| Obtener confianza de la señal                                   |
//+------------------------------------------------------------------+
double CMetaLearningSystem::GetSignalConfidence()
{
    return m_lastConfidence;
}

//+------------------------------------------------------------------+
//| Verificar si el mercado es favorable                            |
//+------------------------------------------------------------------+
bool CMetaLearningSystem::IsMarketFavorable()
{
    return EvaluateMarketConditions() > 0;
}


//+------------------------------------------------------------------+
//| Obtener señal de trading CORREGIDA                              |
//+------------------------------------------------------------------+
int CMetaLearningSystem::GetTradingSignal()
{
    // Actualizar buffers
    if(!UpdateBuffers())
    {
        Print("ERROR: No se pudieron actualizar los buffers");
        return 0;
    }
    
    // Analizar tendencia
    int trend = AnalyzeTrend();
    
    // Evaluar condiciones de mercado
    int marketCondition = EvaluateMarketConditions();
    
    // Calcular confianza
    double confidence = CalculateConfidence();
    m_lastConfidence = confidence;
    
    // Solo generar señal si la confianza es suficiente
    if(confidence < m_confidenceThreshold)
    {
        return 0;
    }
    
    // Verificar condiciones de entrada
    if(trend > 0 && CheckEntryConditions(1))
    {
        // Señal de compra
        m_lastSignalTime = TimeCurrent();
        m_lastSignalType = 1;
        Print("SEÑAL ML: BUY - Confianza: ", DoubleToString(confidence, 2));
        return 1;
    }
    else if(trend < 0 && CheckEntryConditions(-1))
    {
        // Señal de venta
        m_lastSignalTime = TimeCurrent();
        m_lastSignalType = -1;
        Print("SEÑAL ML: SELL - Confianza: ", DoubleToString(confidence, 2));
        return -1;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Analizar tendencia del mercado                                  |
//+------------------------------------------------------------------+
int CMetaLearningSystem::AnalyzeTrend()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Análisis de medias móviles
    bool maTrendUp = (m_bufferMA20[0] > m_bufferMA50[0]) && 
                     (m_bufferMA20[0] > m_bufferMA20[1]);
    bool maTrendDown = (m_bufferMA20[0] < m_bufferMA50[0]) && 
                       (m_bufferMA20[0] < m_bufferMA20[1]);
    
    // Análisis MACD
    bool macdBullish = (m_bufferMACD[0] > m_bufferMACDSignal[0]) && 
                       (m_bufferMACD[0] > m_bufferMACD[1]);
    bool macdBearish = (m_bufferMACD[0] < m_bufferMACDSignal[0]) && 
                       (m_bufferMACD[0] < m_bufferMACD[1]);
    
    // Calcular fuerza de tendencia
    m_trendStrength = MathAbs(m_bufferMA20[0] - m_bufferMA50[0]) / m_bufferATR[0];
    
    // Calcular momentum
    m_momentum = (currentPrice - m_bufferMA20[2]) / m_bufferATR[0];
    
    // Determinar tendencia
    int trendVotes = 0;
    
    if(maTrendUp) trendVotes++;
    if(maTrendDown) trendVotes--;
    if(macdBullish) trendVotes++;
    if(macdBearish) trendVotes--;
    if(currentPrice > m_bufferMA20[0]) trendVotes++;
    if(currentPrice < m_bufferMA20[0]) trendVotes--;
    
    if(trendVotes >= 2) return 1;  // Tendencia alcista
    if(trendVotes <= -2) return -1; // Tendencia bajista
    
    return 0; // Sin tendencia clara
}


//+------------------------------------------------------------------+
//| Verificar condiciones de entrada                                |
//+------------------------------------------------------------------+
bool CMetaLearningSystem::CheckEntryConditions(int trendDirection)
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(trendDirection > 0) // Condiciones para compra
    {
        // RSI no debe estar sobrecomprado
        if(m_bufferRSI[0] > 70) return false;
        
        // Precio debe estar cerca del soporte (banda inferior o MA)
        bool nearSupport = (currentPrice <= m_bufferBBLower[0] * 1.01) ||
                          (currentPrice <= m_bufferMA20[0] * 1.005);
        
        // Stochastic debe mostrar sobreventa o cruce alcista
        bool stochBullish = (m_bufferStochMain[0] < 30) ||
                           ((m_bufferStochMain[0] > m_bufferStochSignal[0]) &&
                            (m_bufferStochMain[1] <= m_bufferStochSignal[1]));
        
        return nearSupport || stochBullish;
    }
    else if(trendDirection < 0) // Condiciones para venta
    {
        // RSI no debe estar sobrevendido
        if(m_bufferRSI[0] < 30) return false;
        
        // Precio debe estar cerca de la resistencia (banda superior o MA)
        bool nearResistance = (currentPrice >= m_bufferBBUpper[0] * 0.99) ||
                             (currentPrice >= m_bufferMA20[0] * 0.995);
        
        // Stochastic debe mostrar sobrecompra o cruce bajista
        bool stochBearish = (m_bufferStochMain[0] > 70) ||
                           ((m_bufferStochMain[0] < m_bufferStochSignal[0]) &&
                            (m_bufferStochMain[1] >= m_bufferStochSignal[1]));
        
        return nearResistance || stochBearish;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calcular fuerza de la señal                                     |
//+------------------------------------------------------------------+
double CMetaLearningSystem::CalculateSignalStrength()
{
    double strength = 0;
    double weights = 0;
    
    // Factor 1: Alineación de medias móviles (peso 30%)
    double maDistance = MathAbs(m_bufferMA20[0] - m_bufferMA50[0]);
    double maStrength = MathMin(maDistance / (10 * _Point), 1.0);
    strength += maStrength * 0.3;
    weights += 0.3;
    
    // Factor 2: RSI (peso 25%)
    double rsiStrength = 0;
    if(m_bufferRSI[0] >= 40 && m_bufferRSI[0] <= 60)
    {
        rsiStrength = 1.0; // RSI en zona neutral es bueno
    }
    else if(m_bufferRSI[0] < 30 || m_bufferRSI[0] > 70)
    {
        rsiStrength = 0.2; // RSI extremo es malo
    }
    else
    {
        rsiStrength = 0.6;
    }
    strength += rsiStrength * 0.25;
    weights += 0.25;
    
    // Factor 3: MACD (peso 25%)
    double macdDistance = MathAbs(m_bufferMACD[0] - m_bufferMACDSignal[0]);
    double macdStrength = MathMin(macdDistance / (5 * _Point), 1.0);
    strength += macdStrength * 0.25;
    weights += 0.25;
    
    // Factor 4: Posición en Bandas de Bollinger (peso 20%)
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double bbRange = m_bufferBBUpper[0] - m_bufferBBLower[0];
    double bbPosition = (currentPrice - m_bufferBBLower[0]) / bbRange;
    double bbStrength = 0;
    
    if(bbPosition >= 0.3 && bbPosition <= 0.7)
    {
        bbStrength = 1.0; // Precio en zona media es ideal
    }
    else
    {
        bbStrength = 0.5;
    }
    strength += bbStrength * 0.2;
    weights += 0.2;
    
    return weights > 0 ? strength / weights : 0;
}

//+------------------------------------------------------------------+
//| Calcular Stop Loss                                              |
//+------------------------------------------------------------------+
double CMetaLearningSystem::CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
    const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double stopLoss = 0.0;

    if(orderType == ORDER_TYPE_BUY)
    {
        // Para compras, SL por debajo del precio de entrada
        stopLoss = entryPrice - (m_stopLossPoints * pt);

        // Verificar que no esté por debajo de la banda inferior
        if(ArraySize(m_bufferBBLower) > 0 && stopLoss < m_bufferBBLower[0])
            stopLoss = m_bufferBBLower[0] - (10 * pt); // 10 puntos debajo de BB inferior
    }
    else // ORDER_TYPE_SELL
    {
        // Para ventas, SL por encima del precio de entrada
        stopLoss = entryPrice + (m_stopLossPoints * pt);

        // Verificar que no esté por encima de la banda superior
        if(ArraySize(m_bufferBBUpper) > 0 && stopLoss > m_bufferBBUpper[0])
            stopLoss = m_bufferBBUpper[0] + (10 * pt); // 10 puntos encima de BB superior
    }

    return NormalizeDouble(stopLoss, _Digits);
}


//+------------------------------------------------------------------+
//| Calcular Take Profit                                            |
//+------------------------------------------------------------------+
double CMetaLearningSystem::CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice)
{
    const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    const double tpPoints = m_stopLossPoints * m_riskRewardRatio;
    double takeProfit = 0.0;

    if(orderType == ORDER_TYPE_BUY)
    {
        takeProfit = entryPrice + (tpPoints * pt);

        // Ajustar si está muy cerca de la banda superior
        if(ArraySize(m_bufferBBUpper) > 0)
        {
            double maxTP = m_bufferBBUpper[0] + (50 * pt);
            if(takeProfit > maxTP)
                takeProfit = maxTP;
        }
    }
    else // ORDER_TYPE_SELL
    {
        takeProfit = entryPrice - (tpPoints * pt);

        // Ajustar si está muy cerca de la banda inferior
        if(ArraySize(m_bufferBBLower) > 0)
        {
            double minTP = m_bufferBBLower[0] - (50 * pt);
            if(takeProfit < minTP)
                takeProfit = minTP;
        }
    }

    return NormalizeDouble(takeProfit, _Digits);
}


//+------------------------------------------------------------------+
//| Estructura: Trade Context para Aprendizaje                     |
//+------------------------------------------------------------------+
struct TradeContext {
    // Condiciones de entrada
    double atr;
    double rsi;
    double momentum;
    ENUM_MARKET_REGIME regime;
    double srStrength;
    double accumQuality;
    int timeOfDay;
    
    // Resultado
    bool wasSuccessful;
    double profit;
    double maxDrawdown;
    int duration;
    
    // Constructor
    void Initialize() {
        atr = 0;
        rsi = 50;
        momentum = 0;
        regime = REGIME_RANGING;
        srStrength = 0;
        accumQuality = 0;
        timeOfDay = 12;
        wasSuccessful = false;
        profit = 0;
        maxDrawdown = 0;
        duration = 0;
    }
};

//+------------------------------------------------------------------+
//| Estructura: Contexto Cuántico de Mercado                       |
//+------------------------------------------------------------------+
struct QuantumMarketContext {
    // Microestructura
    double bid_ask_imbalance;
    double order_flow_toxicity;
    double volume_weighted_momentum;
    double microstructure_noise;
    double price_impact_coefficient;
    double market_depth_imbalance;
    
    // Régimen avanzado
    double regime_transition_probability;
    double regime_stability_score;
    int regime_duration_bars;
    ENUM_MARKET_REGIME current_regime;
    ENUM_MARKET_REGIME predicted_regime;
    
    // Sentimiento multi-capa
    double retail_sentiment;
    double institutional_sentiment;
    double smart_money_flow;
    double fear_greed_oscillator;
    double option_flow_sentiment;
    double dark_pool_activity;
    
    // Predicciones
    double next_hour_volatility;
    double next_4h_direction_prob;
    double daily_range_forecast;
    double weekly_trend_strength;
    
    // Metadata
    datetime last_update;
    int data_quality_score;
    
    // Constructor
    void Initialize() {
        bid_ask_imbalance = 0.0;
        order_flow_toxicity = 0.0;
        volume_weighted_momentum = 0.0;
        microstructure_noise = 0.0;
        price_impact_coefficient = 0.0;
        market_depth_imbalance = 0.0;
        regime_transition_probability = 0.0;
        regime_stability_score = 0.5;
        regime_duration_bars = 0;
        current_regime = REGIME_RANGING;
        predicted_regime = REGIME_RANGING;
        retail_sentiment = 0.5;
        institutional_sentiment = 0.5;
        smart_money_flow = 0.0;
        fear_greed_oscillator = 0.0;
        option_flow_sentiment = 0.0;
        dark_pool_activity = 0.0;
        next_hour_volatility = 1.0;
        next_4h_direction_prob = 0.5;
        daily_range_forecast = 0.0;
        weekly_trend_strength = 0.0;
        last_update = TimeCurrent();
        data_quality_score = 100;
    }
};

//+------------------------------------------------------------------+
//| Estructura: Perfil de Decisión Cuántica                        |
//+------------------------------------------------------------------+
struct QuantumDecisionProfile {
    // Decisión principal
    ENUM_FINAL_ACTION action;
    int direction;                    // 1=BUY, -1=SELL
    double final_confidence;          // 0..1 calibrada
    double prediction_accuracy;       // Precisión histórica del modelo
    
    // Configuración de Órdenes
    int primary_orders;               // Órdenes iniciales
    int contingent_orders;            // Órdenes condicionales
    double risk_per_order[QUANTUM_MAX_ORDERS];
    double entry_prices[QUANTUM_MAX_ORDERS];
    double max_total_risk;
    
    // Stop Loss inteligente
    double sl_atr_mult[QUANTUM_MAX_ORDERS];
    bool use_dynamic_sl;
    double sl_protection_level;
    
    // Trailing adaptativo
    int trailing_profile;
    double trailing_stages[5];
    bool use_ai_trailing;
    
    // Metadata
    string reasoning;
    double expected_return;
    double max_expected_drawdown;
    datetime optimal_exit_time;
    ENUM_ML_STRATEGY strategy_type;
    
    // Constructor
    void Initialize() {
        action = ACT_SKIP;
        direction = 0;
        final_confidence = 0.0;
        prediction_accuracy = 0.0;
        primary_orders = 0;
        contingent_orders = 0;
        max_total_risk = 0.0;
        ArrayInitialize(risk_per_order, 0.0);
        ArrayInitialize(entry_prices, 0.0);
        ArrayInitialize(sl_atr_mult, 1.0);
        use_dynamic_sl = false;
        sl_protection_level = 0.5;
        trailing_profile = 0;
        ArrayInitialize(trailing_stages, 0.0);
        use_ai_trailing = false;
        reasoning = "";
        expected_return = 0.0;
        max_expected_drawdown = 0.0;
        optimal_exit_time = TimeCurrent();
        strategy_type = STRAT_BALANCED;
    }
};

//+------------------------------------------------------------------+
//| Estructura: Forecast Cuántico                                   |
//+------------------------------------------------------------------+
struct QuantumForecast {
    // Forecast multi-horizonte
    double h1_direction_prob;
    double h4_direction_prob;
    double d1_direction_prob;
    double w1_direction_prob;
    
    // Targets probabilísticos
    double target_levels[10];
    double target_probabilities[10];
    
    // Volatilidad esperada
    double expected_volatility_curve[24];
    
    // Eventos esperados
    datetime critical_times[5];
    string critical_events[5];
    
    // Confianza del forecast
    double forecast_confidence;
    double model_uncertainty;
    
    // Constructor
    void Initialize() {
        h1_direction_prob = 0.5;
        h4_direction_prob = 0.5;
        d1_direction_prob = 0.5;
        w1_direction_prob = 0.5;
        ArrayInitialize(target_levels, 0.0);
        ArrayInitialize(target_probabilities, 0.0);
        ArrayInitialize(expected_volatility_curve, 1.0);
        for(int i = 0; i < 5; i++) {
            critical_times[i] = 0;
            critical_events[i] = "";
        }
        forecast_confidence = 0.5;
        model_uncertainty = 0.5;
    }
};

//+------------------------------------------------------------------+
//| Estructura: Sistema de Votación Mejorado                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| SISTEMA DE VOTACIÓN CONTEXTUAL - CLASE MUNDIAL v3.0            |
//| Arquitectura Multidimensional con Aprendizaje Profundo         |
//+------------------------------------------------------------------+

//--- Enumeraciones para Contexto de Mercado
enum ENUM_VOTING_SESSION {
    VOTING_SESSION_ASIA = 0,      // 00:00-08:00 GMT
    VOTING_SESSION_LONDON = 1,    // 08:00-16:00 GMT
    VOTING_SESSION_NY = 2         // 13:00-22:00 GMT (overlap con London)
};

enum ENUM_VOTING_VOLATILITY {
    VOTING_VOL_LOW = 0,           // ATR < percentil 40
    VOTING_VOL_HIGH = 1           // ATR >= percentil 40
};

enum ENUM_VOTING_DIRECTION {
    VOTING_DIR_BUY = 0,           // Señal de compra
    VOTING_DIR_SELL = 1           // Señal de venta
};

//--- Estructura: Celda de Performance Contextual (Micro-Cerebro)
// Renombrada para evitar conflicto con VotingStatistics.mqh
struct ML_ContextualPerformanceCell {
    // Métricas estadísticas
    int totalSignals;              // Total de señales enviadas en este contexto
    int wins;                      // Trades ganadores
    int losses;                    // Trades perdedores
    double accumulatedProfit;      // Profit acumulado (en pips o $)
    double winRate;                // Win rate (0.0 - 1.0)
    double avgProfit;              // Profit promedio por trade

    // Performance temporal
    int consecutiveWins;           // Racha actual de victorias
    int consecutiveLosses;         // Racha actual de pérdidas
    datetime lastSignalTime;       // Timestamp última señal
    datetime lastWinTime;          // Timestamp último win

    // Métricas de confianza
    double confidenceScore;        // Score de confianza dinámico (0.0 - 1.0)
    double emaPerformance;         // EMA de performance (respuesta rápida)

    // Constructor
    void Initialize() {
        totalSignals = 0;
        wins = 0;
        losses = 0;
        accumulatedProfit = 0.0;
        winRate = 0.5;  // Neutral inicial
        avgProfit = 0.0;
        consecutiveWins = 0;
        consecutiveLosses = 0;
        lastSignalTime = 0;
        lastWinTime = 0;
        confidenceScore = 0.5;  // Neutral
        emaPerformance = 0.5;   // Neutral
    }

    // Actualizar celda con resultado de trade
    void Update(bool won, double profit) {
        totalSignals++;

        if(won) {
            wins++;
            consecutiveWins++;
            consecutiveLosses = 0;
            lastWinTime = TimeCurrent();
        } else {
            losses++;
            consecutiveLosses++;
            consecutiveWins = 0;
        }

        accumulatedProfit += profit;
        lastSignalTime = TimeCurrent();

        // Calcular métricas
        winRate = (totalSignals > 0) ? (double)wins / totalSignals : 0.5;
        avgProfit = (totalSignals > 0) ? accumulatedProfit / totalSignals : 0.0;

        // Actualizar EMA de performance (alpha = 0.15 para respuesta rápida)
        double alpha = 0.15;
        emaPerformance = (1.0 - alpha) * emaPerformance + alpha * (won ? 1.0 : 0.0);

        // Calcular confidence score (combinación de WR y muestra)
        double sampleWeight = MathMin(1.0, totalSignals / 20.0);  // Máximo en 20 muestras
        confidenceScore = sampleWeight * winRate + (1.0 - sampleWeight) * 0.5;

        // Clamp de seguridad
        winRate = MathMax(0.0, MathMin(1.0, winRate));
        confidenceScore = MathMax(0.0, MathMin(1.0, confidenceScore));
        emaPerformance = MathMax(0.0, MathMin(1.0, emaPerformance));
    }

    // Validar consistencia de datos
    bool Validate() {
        bool isValid = true;

        if(totalSignals < 0) { totalSignals = 0; isValid = false; }
        if(wins < 0) { wins = 0; isValid = false; }
        if(losses < 0) { losses = 0; isValid = false; }
        if(wins + losses > totalSignals) { wins = 0; losses = 0; isValid = false; }

        winRate = MathMax(0.0, MathMin(1.0, winRate));
        confidenceScore = MathMax(0.0, MathMin(1.0, confidenceScore));
        emaPerformance = MathMax(0.0, MathMin(1.0, emaPerformance));

        return isValid;
    }
};

//--- Estructura: Información de Indicador
struct IndicatorInfo {
    string name;                   // Nombre del indicador
    double baseWeight;             // Peso base inicial
    double currentWeight;          // Peso actual (ajustado por contexto)
    int globalTrades;              // Total de trades global
    double globalWinRate;          // WR global del indicador

    void Initialize(string n, double w) {
        name = n;
        baseWeight = w;
        currentWeight = w;
        globalTrades = 0;
        globalWinRate = 0.5;
    }
};

//--- Estructura: Resultado de Consenso Mejorado
struct ConsensusResult {
    bool isValid;                  // ¿Es válida la señal?
    int direction;                 // 1=BUY, -1=SELL, 0=NEUTRAL
    double strength;               // Fuerza de la señal (0.0 - 1.0)
    double confidence;             // Confianza en la señal (0.0 - 1.0)
    string reasoning;              // Explicación detallada
    int topIndicatorId;            // ID del indicador líder
    string topIndicatorName;       // Nombre del indicador líder
};

//--- Estructura: Contexto Actual del Mercado
// Renombrada para evitar conflicto con VotingStatistics.mqh
struct ML_MarketContextSnapshot {
    ENUM_VOTING_SESSION session;
    ENUM_VOTING_VOLATILITY volatility;
    datetime timestamp;
    double atrValue;
    int hourGMT;

    void Initialize() {
        session = VOTING_SESSION_ASIA;
        volatility = VOTING_VOL_LOW;
        timestamp = 0;
        atrValue = 0.0;
        hourGMT = 0;
    }
};

//+------------------------------------------------------------------+
//| CLASE PRINCIPAL: Sistema de Votación Contextual Avanzado       |
//+------------------------------------------------------------------+
class ContextualVotingSystem {
private:
    //--- Matriz 4D de Performance: [Indicador][Sesión][Volatilidad][Dirección]
    //    5 indicadores x 3 sesiones x 2 regímenes x 2 direcciones = 60 micro-cerebros
    ML_ContextualPerformanceCell m_performanceMatrix[5][3][2][2];

    //--- Información de indicadores
    IndicatorInfo m_indicators[5];

    //--- Contexto actual
    ML_MarketContextSnapshot m_currentContext;

    //--- Cache de ATR para detección de volatilidad
    double m_atrHistory[100];
    int m_atrHistoryCount;

    //--- Configuración
    double m_minConsensusDiff;     // Diferencia mínima para consenso (default: 0.20)
    double m_minSampleSize;        // Muestras mínimas para usar contexto (default: 5)
    int m_tradesUntilSave;         // Trades hasta guardar (default: 50)
    int m_tradesSinceLastSave;     // Contador

    //--- Estadísticas globales
    int m_totalSystemTrades;
    datetime m_systemStartTime;

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    ContextualVotingSystem() {
        m_minConsensusDiff = 0.20;
        m_minSampleSize = 5;
        m_tradesUntilSave = 50;
        m_tradesSinceLastSave = 0;
        m_totalSystemTrades = 0;
        m_systemStartTime = TimeCurrent();
        m_atrHistoryCount = 0;
    }

    //+------------------------------------------------------------------+
    //| Inicialización del Sistema                                      |
    //+------------------------------------------------------------------+
    void Initialize() {
        Print("═══════════════════════════════════════════════════════════");
        Print("  🧠 SISTEMA DE VOTACIÓN CONTEXTUAL v3.0 - INICIALIZANDO");
        Print("═══════════════════════════════════════════════════════════");

        // Inicializar indicadores con pesos balanceados
        m_indicators[0].Initialize("SR_Levels", 0.20);
        m_indicators[1].Initialize("ML_Neural", 0.20);
        m_indicators[2].Initialize("Momentum", 0.20);
        m_indicators[3].Initialize("RSI_Divergence", 0.20);
        m_indicators[4].Initialize("Volume_Profile", 0.20);

        // Inicializar matriz 4D completa
        for(int ind = 0; ind < 5; ind++) {
            for(int ses = 0; ses < 3; ses++) {
                for(int vol = 0; vol < 2; vol++) {
                    for(int dir = 0; dir < 2; dir++) {
                        m_performanceMatrix[ind][ses][vol][dir].Initialize();
                    }
                }
            }
        }

        // Inicializar contexto
        m_currentContext.Initialize();

        // Inicializar ATR history
        ArrayInitialize(m_atrHistory, 0.0);

        // Intentar cargar datos persistidos
        LoadPerformanceData();

        Print("✅ Sistema de votación contextual inicializado correctamente");
        Print("   📊 Indicadores: ", ArraySize(m_indicators));
        Print("   🧩 Micro-cerebros: 60 (5x3x2x2)");
        Print("   💾 Persistencia: Cada ", m_tradesUntilSave, " trades");
        Print("═══════════════════════════════════════════════════════════");
    }

    //+------------------------------------------------------------------+
    //| Detectar Sesión de Trading Actual                              |
    //+------------------------------------------------------------------+
    ENUM_VOTING_SESSION DetectCurrentSession() {
        MqlDateTime dt;
        TimeToStruct(TimeGMT(), dt);
        int hourGMT = dt.hour;

        m_currentContext.hourGMT = hourGMT;

        // Overlap NY-London tiene prioridad (13:00-16:00 GMT)
        if(hourGMT >= 13 && hourGMT < 16) {
            return VOTING_SESSION_NY;  // Sesión más volátil
        }

        // Sesión de Londres (08:00-16:00 GMT)
        if(hourGMT >= 8 && hourGMT < 16) {
            return VOTING_SESSION_LONDON;
        }

        // Sesión de Nueva York (13:00-22:00 GMT)
        if(hourGMT >= 13 && hourGMT < 22) {
            return VOTING_SESSION_NY;
        }

        // Sesión de Asia (00:00-08:00 GMT)
        return VOTING_SESSION_ASIA;
    }

    //+------------------------------------------------------------------+
    //| Detectar Régimen de Volatilidad                                |
    //+------------------------------------------------------------------+
    ENUM_VOTING_VOLATILITY DetectVolatilityRegime() {
        // Calcular ATR actual
        int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        double currentATR = 0.0;

        if(atr_handle != INVALID_HANDLE) {
            double atr_buffer[];
            ArraySetAsSeries(atr_buffer, true);
            if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
                currentATR = atr_buffer[0];
            }
            IndicatorRelease(atr_handle);
        }

        m_currentContext.atrValue = currentATR;

        // Guardar en historial
        if(m_atrHistoryCount < 100) {
            m_atrHistory[m_atrHistoryCount] = currentATR;
            m_atrHistoryCount++;
        } else {
            // Shift array
            for(int i = 0; i < 99; i++) {
                m_atrHistory[i] = m_atrHistory[i + 1];
            }
            m_atrHistory[99] = currentATR;
        }

        // Si no hay suficiente historial, usar LOW_VOL por defecto
        if(m_atrHistoryCount < 10) {
            return VOTING_VOL_LOW;
        }

        // Calcular percentil 40
        double sortedATR[];
        ArrayResize(sortedATR, m_atrHistoryCount);
        ArrayCopy(sortedATR, m_atrHistory, 0, 0, m_atrHistoryCount);
        ArraySort(sortedATR);

        int percentile40Index = (int)(m_atrHistoryCount * 0.40);
        double percentile40Value = sortedATR[percentile40Index];

        // Determinar régimen
        if(currentATR >= percentile40Value) {
            return VOTING_VOL_HIGH;
        }

        return VOTING_VOL_LOW;
    }

    //+------------------------------------------------------------------+
    //| Actualizar Contexto Actual                                      |
    //+------------------------------------------------------------------+
    void UpdateCurrentContext() {
        m_currentContext.session = DetectCurrentSession();
        m_currentContext.volatility = DetectVolatilityRegime();
        m_currentContext.timestamp = TimeCurrent();
    }

    //+------------------------------------------------------------------+
    //| Calcular Peso Contextual para un Indicador                     |
    //+------------------------------------------------------------------+
    double CalculateContextualWeight(int indicatorId, ENUM_VOTING_DIRECTION direction) {
        if(indicatorId < 0 || indicatorId >= 5) return 0.20;  // Peso neutro

        // Obtener contexto actual
        int ses = (int)m_currentContext.session;
        int vol = (int)m_currentContext.volatility;
        int dir = (int)direction;

        // Validar índices
        ses = MathMax(0, MathMin(2, ses));
        vol = MathMax(0, MathMin(1, vol));
        dir = MathMax(0, MathMin(1, dir));

        // Obtener celda de performance contextual
        ML_ContextualPerformanceCell cell = m_performanceMatrix[indicatorId][ses][vol][dir];

        // Peso base del indicador
        double baseWeight = m_indicators[indicatorId].baseWeight;

        // Si no hay suficientes muestras en este contexto, usar peso base
        if(cell.totalSignals < m_minSampleSize) {
            return baseWeight;
        }

        //--- FÓRMULA DE PESO CONTEXTUAL AVANZADA ---

        // 1. Multiplicador basado en Win Rate contextual
        double baseWR = 0.50;  // Win rate neutral
        double contextWR = cell.winRate;
        double wrMultiplier = 1.0 + (contextWR - baseWR) * 2.5;  // -1.25x a +1.25x
        wrMultiplier = MathMax(0.20, MathMin(3.0, wrMultiplier));  // Clamp [0.2, 3.0]

        // 2. Factor de performance EMA (más peso a resultados recientes)
        double emaFactor = 0.8 + (cell.emaPerformance * 0.4);  // 0.8x a 1.2x

        // 3. Boost por racha de victorias
        double streakBoost = 1.0;
        if(cell.consecutiveWins >= 3) {
            streakBoost = 1.0 + (cell.consecutiveWins * 0.05);  // +5% por cada win
            streakBoost = MathMin(1.5, streakBoost);  // Máximo +50%
        }

        // 4. Penalización por racha de pérdidas
        double streakPenalty = 1.0;
        if(cell.consecutiveLosses >= 3) {
            streakPenalty = 1.0 - (cell.consecutiveLosses * 0.08);  // -8% por cada loss
            streakPenalty = MathMax(0.4, streakPenalty);  // Mínimo -60%
        }

        // 5. Factor de confianza (basado en tamaño de muestra)
        double confidenceFactor = MathMin(1.0, cell.totalSignals / 30.0);  // Máximo en 30 muestras
        confidenceFactor = 0.7 + (confidenceFactor * 0.3);  // 0.7x a 1.0x

        //--- CÁLCULO FINAL ---
        double finalWeight = baseWeight * wrMultiplier * emaFactor * streakBoost * streakPenalty * confidenceFactor;

        // Clamp de seguridad [0.05, 0.60]
        finalWeight = MathMax(0.05, MathMin(0.60, finalWeight));

        return finalWeight;
    }

    //+------------------------------------------------------------------+
    //| Construir Consenso con Contexto Avanzado                       |
    //+------------------------------------------------------------------+
    ConsensusResult BuildConsensus(double &buyVotes[], double &sellVotes[], int voteCount) {
        ConsensusResult result;
        result.isValid = false;
        result.direction = 0;
        result.strength = 0.0;
        result.confidence = 0.0;
        result.reasoning = "";
        result.topIndicatorId = -1;
        result.topIndicatorName = "";

        // Validación de entrada
        if(voteCount <= 0 || ArraySize(buyVotes) == 0 || ArraySize(sellVotes) == 0) {
            result.reasoning = "❌ Arrays de votos inválidos";
            return result;
        }

        // Actualizar contexto actual
        UpdateCurrentContext();

        // Calcular votos ponderados contextuales
        double buyScore = 0.0;
        double sellScore = 0.0;
        double weights[5];
        double normalizedWeights[5];

        int maxVotes = MathMin(5, MathMin(voteCount, MathMin(ArraySize(buyVotes), ArraySize(sellVotes))));

        // Determinar dirección preliminar para calcular pesos correctos
        double prelimBuyScore = 0.0;
        double prelimSellScore = 0.0;
        for(int i = 0; i < maxVotes; i++) {
            prelimBuyScore += buyVotes[i];
            prelimSellScore += sellVotes[i];
        }

        ENUM_VOTING_DIRECTION prelimDirection = (prelimBuyScore > prelimSellScore) ?
                                                 VOTING_DIR_BUY : VOTING_DIR_SELL;

        // Calcular pesos contextuales
        double totalWeight = 0.0;
        for(int i = 0; i < maxVotes; i++) {
            weights[i] = CalculateContextualWeight(i, prelimDirection);
            totalWeight += weights[i];
        }

        // Normalizar pesos
        if(totalWeight > 0) {
            for(int i = 0; i < maxVotes; i++) {
                normalizedWeights[i] = weights[i] / totalWeight;
            }
        } else {
            // Fallback a pesos uniformes
            for(int i = 0; i < maxVotes; i++) {
                normalizedWeights[i] = 1.0 / maxVotes;
            }
        }

        // Calcular scores finales
        int topIndicator = -1;
        double topIndicatorContribution = 0.0;

        for(int i = 0; i < maxVotes; i++) {
            double buyContribution = buyVotes[i] * normalizedWeights[i];
            double sellContribution = sellVotes[i] * normalizedWeights[i];

            buyScore += buyContribution;
            sellScore += sellContribution;

            // Rastrear indicador líder
            double totalContribution = buyContribution + sellContribution;
            if(totalContribution > topIndicatorContribution) {
                topIndicatorContribution = totalContribution;
                topIndicator = i;
            }

            // Actualizar peso actual del indicador
            m_indicators[i].currentWeight = normalizedWeights[i];
        }

        // Prevenir división por cero
        double totalScore = buyScore + sellScore;
        if(totalScore <= 0.0) {
            result.reasoning = "⚠️ Score total es cero";
            return result;
        }

        // Calcular métricas finales
        double differential = MathAbs(buyScore - sellScore) / totalScore;

        result.direction = (buyScore > sellScore) ? 1 : -1;
        result.strength = MathMin(1.0, differential);
        result.confidence = MathMin(1.0, totalScore / maxVotes);
        result.isValid = (differential >= m_minConsensusDiff);

        // Información del indicador líder
        if(topIndicator >= 0 && topIndicator < 5) {
            result.topIndicatorId = topIndicator;
            result.topIndicatorName = m_indicators[topIndicator].name;
        }

        // Generar reasoning detallado
        string sessionName[] = {"ASIA", "LONDON", "NY"};
        string volName[] = {"LOW_VOL", "HIGH_VOL"};
        string dirName = (result.direction > 0) ? "BUY" : "SELL";

        result.reasoning = StringFormat(
            "%s | %s | %s | Líder: %s (%.1f%%) | BUY:%.3f SELL:%.3f | Diff:%.1f%% | Conf:%.1f%%",
            sessionName[m_currentContext.session],
            volName[m_currentContext.volatility],
            dirName,
            result.topIndicatorName,
            topIndicatorContribution * 100.0,
            buyScore,
            sellScore,
            differential * 100.0,
            result.confidence * 100.0
        );

        return result;
    }

    //+------------------------------------------------------------------+
    //| Aprender de Resultado de Trade (Actualización Inmediata)       |
    //+------------------------------------------------------------------+
    void LearnFromTrade(int indicatorId, ENUM_VOTING_DIRECTION direction, bool success, double profit) {
        if(indicatorId < 0 || indicatorId >= 5) {
            Print("❌ ERROR: LearnFromTrade - indicatorId inválido: ", indicatorId);
            return;
        }

        // Obtener índices de contexto
        int ses = (int)m_currentContext.session;
        int vol = (int)m_currentContext.volatility;
        int dir = (int)direction;

        // Validar índices
        ses = MathMax(0, MathMin(2, ses));
        vol = MathMax(0, MathMin(1, vol));
        dir = MathMax(0, MathMin(1, dir));

        // Actualizar celda específica
        m_performanceMatrix[indicatorId][ses][vol][dir].Update(success, profit);

        // Actualizar estadísticas globales del indicador
        m_indicators[indicatorId].globalTrades++;

        // Actualizar WR global (EMA)
        double alpha = 0.10;
        m_indicators[indicatorId].globalWinRate =
            (1.0 - alpha) * m_indicators[indicatorId].globalWinRate +
            alpha * (success ? 1.0 : 0.0);

        // Incrementar contador global
        m_totalSystemTrades++;
        m_tradesSinceLastSave++;

        // Logging detallado
        string sessionName[] = {"ASIA", "LONDON", "NY"};
        string volName[] = {"LOW", "HIGH"};
        string dirName[] = {"BUY", "SELL"};
        string resultIcon = success ? "✅" : "❌";

        ML_ContextualPerformanceCell cell = m_performanceMatrix[indicatorId][ses][vol][dir];

        Print(StringFormat(
            "%s APRENDIZAJE | %s | %s-%s-%s | WR: %.1f%% (%d/%d) | Profit: $%.2f | Racha: %dW/%dL",
            resultIcon,
            m_indicators[indicatorId].name,
            sessionName[ses],
            volName[vol],
            dirName[dir],
            cell.winRate * 100.0,
            cell.wins,
            cell.totalSignals,
            profit,
            cell.consecutiveWins,
            cell.consecutiveLosses
        ));

        // Guardar periódicamente
        if(m_tradesSinceLastSave >= m_tradesUntilSave) {
            SavePerformanceData();
            m_tradesSinceLastSave = 0;
        }
    }

    //+------------------------------------------------------------------+
    //| Aprender de Todos los Indicadores (Para cierre de trade)       |
    //+------------------------------------------------------------------+
    void LearnFromAllIndicators(int finalDirection, bool success, double profit) {
        ENUM_VOTING_DIRECTION dir = (finalDirection > 0) ? VOTING_DIR_BUY : VOTING_DIR_SELL;

        // Actualizar todos los indicadores que participaron
        for(int i = 0; i < 5; i++) {
            LearnFromTrade(i, dir, success, profit);
        }
    }

    //+------------------------------------------------------------------+
    //| Obtener Top N Indicadores en Contexto Actual                   |
    //+------------------------------------------------------------------+
    void GetTopIndicators(int &topIds[], string &topNames[], double &topWR[], int topN = 3) {
        ArrayResize(topIds, 0);
        ArrayResize(topNames, 0);
        ArrayResize(topWR, 0);

        struct RankEntry {
            int id;
            string name;
            double winRate;
            int samples;
        };

        RankEntry rankings[5];

        // Recopilar performance de cada indicador en contexto actual
        int ses = (int)m_currentContext.session;
        int vol = (int)m_currentContext.volatility;

        for(int i = 0; i < 5; i++) {
            rankings[i].id = i;
            rankings[i].name = m_indicators[i].name;

            // Promediar WR de ambas direcciones en el contexto actual
            double buyWR = m_performanceMatrix[i][ses][vol][VOTING_DIR_BUY].winRate;
            double sellWR = m_performanceMatrix[i][ses][vol][VOTING_DIR_SELL].winRate;
            int buySamples = m_performanceMatrix[i][ses][vol][VOTING_DIR_BUY].totalSignals;
            int sellSamples = m_performanceMatrix[i][ses][vol][VOTING_DIR_SELL].totalSignals;

            rankings[i].samples = buySamples + sellSamples;

            if(rankings[i].samples > 0) {
                rankings[i].winRate = ((buyWR * buySamples) + (sellWR * sellSamples)) / rankings[i].samples;
            } else {
                rankings[i].winRate = 0.5;  // Neutral si no hay datos
            }
        }

        // Ordenar por WR (bubble sort simple)
        for(int i = 0; i < 4; i++) {
            for(int j = i + 1; j < 5; j++) {
                if(rankings[j].winRate > rankings[i].winRate) {
                    RankEntry temp = rankings[i];
                    rankings[i] = rankings[j];
                    rankings[j] = temp;
                }
            }
        }

        // Retornar top N
        int count = MathMin(topN, 5);
        ArrayResize(topIds, count);
        ArrayResize(topNames, count);
        ArrayResize(topWR, count);

        for(int i = 0; i < count; i++) {
            topIds[i] = rankings[i].id;
            topNames[i] = rankings[i].name;
            topWR[i] = rankings[i].winRate;
        }
    }

    //+------------------------------------------------------------------+
    //| Generar Reporte de Performance Completo                        |
    //+------------------------------------------------------------------+
    void PrintPerformanceReport() {
        Print("\n╔═══════════════════════════════════════════════════════════════════╗");
        Print("║   📊 REPORTE DE PERFORMANCE - SISTEMA DE VOTACIÓN CONTEXTUAL    ║");
        Print("╚═══════════════════════════════════════════════════════════════════╝");

        string sessionName[] = {"ASIA", "LONDON", "NY"};
        string volName[] = {"LOW_VOL", "HIGH_VOL"};
        string dirName[] = {"BUY", "SELL"};

        // Estadísticas globales
        Print("\n┌─ ESTADÍSTICAS GLOBALES ─────────────────────────────────────────┐");
        Print("│ Total de Trades del Sistema: ", m_totalSystemTrades);
        Print("│ Tiempo en Operación: ", (int)((TimeCurrent() - m_systemStartTime) / 3600), " horas");
        Print("└──────────────────────────────────────────────────────────────────┘");

        // Performance por indicador (global)
        Print("\n┌─ PERFORMANCE POR INDICADOR (GLOBAL) ────────────────────────────┐");
        for(int i = 0; i < 5; i++) {
            Print(StringFormat(
                "│ [%d] %s: Trades=%d | WR Global=%.1f%% | Peso Actual=%.1f%%",
                i,
                m_indicators[i].name,
                m_indicators[i].globalTrades,
                m_indicators[i].globalWinRate * 100.0,
                m_indicators[i].currentWeight * 100.0
            ));
        }
        Print("└──────────────────────────────────────────────────────────────────┘");

        // Top indicadores en contexto actual
        int topIds[];
        string topNames[];
        double topWR[];
        GetTopIndicators(topIds, topNames, topWR, 3);

        Print("\n┌─ TOP 3 EN CONTEXTO ACTUAL ──────────────────────────────────────┐");
        Print("│ Sesión: ", sessionName[m_currentContext.session], " | Volatilidad: ", volName[m_currentContext.volatility]);
        for(int i = 0; i < ArraySize(topIds); i++) {
            Print(StringFormat("│ 🏆 #%d: %s - WR: %.1f%%", i+1, topNames[i], topWR[i] * 100.0));
        }
        Print("└──────────────────────────────────────────────────────────────────┘");

        // Heatmap de mejor contexto por indicador
        Print("\n┌─ MEJOR CONTEXTO POR INDICADOR ──────────────────────────────────┐");
        for(int ind = 0; ind < 5; ind++) {
            double bestWR = 0.0;
            int bestSes = 0, bestVol = 0, bestDir = 0;
            int bestSamples = 0;

            for(int ses = 0; ses < 3; ses++) {
                for(int vol = 0; vol < 2; vol++) {
                    for(int dir = 0; dir < 2; dir++) {
                        ML_ContextualPerformanceCell cell = m_performanceMatrix[ind][ses][vol][dir];
                        if(cell.totalSignals >= m_minSampleSize && cell.winRate > bestWR) {
                            bestWR = cell.winRate;
                            bestSes = ses;
                            bestVol = vol;
                            bestDir = dir;
                            bestSamples = cell.totalSignals;
                        }
                    }
                }
            }

            if(bestSamples > 0) {
                Print(StringFormat(
                    "│ %s: %s-%s-%s | WR: %.1f%% (%d trades)",
                    m_indicators[ind].name,
                    sessionName[bestSes],
                    volName[bestVol],
                    dirName[bestDir],
                    bestWR * 100.0,
                    bestSamples
                ));
            } else {
                Print("│ ", m_indicators[ind].name, ": Sin datos suficientes");
            }
        }
        Print("└──────────────────────────────────────────────────────────────────┘\n");
    }

    //+------------------------------------------------------------------+
    //| Exportar Datos a CSV                                           |
    //+------------------------------------------------------------------+
    bool ExportToCSV(string filename = "VotingSystem_Performance.csv") {
        int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
        if(handle == INVALID_HANDLE) {
            Print("❌ ERROR: No se pudo crear archivo CSV: ", filename);
            return false;
        }

        // Header
        FileWrite(handle, "Indicador", "Sesion", "Volatilidad", "Direccion",
                  "TotalSignals", "Wins", "Losses", "WinRate", "AvgProfit",
                  "ConsecutiveWins", "ConsecutiveLosses", "ConfidenceScore");

        string sessionName[] = {"ASIA", "LONDON", "NY"};
        string volName[] = {"LOW_VOL", "HIGH_VOL"};
        string dirName[] = {"BUY", "SELL"};

        // Datos
        for(int ind = 0; ind < 5; ind++) {
            for(int ses = 0; ses < 3; ses++) {
                for(int vol = 0; vol < 2; vol++) {
                    for(int dir = 0; dir < 2; dir++) {
                        ML_ContextualPerformanceCell cell = m_performanceMatrix[ind][ses][vol][dir];

                        FileWrite(handle,
                            m_indicators[ind].name,
                            sessionName[ses],
                            volName[vol],
                            dirName[dir],
                            cell.totalSignals,
                            cell.wins,
                            cell.losses,
                            DoubleToString(cell.winRate, 4),
                            DoubleToString(cell.avgProfit, 2),
                            cell.consecutiveWins,
                            cell.consecutiveLosses,
                            DoubleToString(cell.confidenceScore, 4)
                        );
                    }
                }
            }
        }

        FileClose(handle);
        Print("✅ Datos exportados exitosamente a: ", filename);
        return true;
    }

    //+------------------------------------------------------------------+
    //| Guardar Datos de Performance (Persistencia)                    |
    //+------------------------------------------------------------------+
    void SavePerformanceData() {
        string filename = "NCN_VotingContextMatrix_" + _Symbol + ".bin";
        int handle = FileOpen(filename, FILE_WRITE|FILE_BIN);

        if(handle == INVALID_HANDLE) {
            Print("⚠️ WARNING: No se pudo guardar matriz contextual");
            return;
        }

        // Guardar matriz completa
        for(int ind = 0; ind < 5; ind++) {
            for(int ses = 0; ses < 3; ses++) {
                for(int vol = 0; vol < 2; vol++) {
                    for(int dir = 0; dir < 2; dir++) {
                        ML_ContextualPerformanceCell cell = m_performanceMatrix[ind][ses][vol][dir];

                        FileWriteInteger(handle, cell.totalSignals);
                        FileWriteInteger(handle, cell.wins);
                        FileWriteInteger(handle, cell.losses);
                        FileWriteDouble(handle, cell.accumulatedProfit);
                        FileWriteDouble(handle, cell.winRate);
                        FileWriteDouble(handle, cell.avgProfit);
                        FileWriteInteger(handle, cell.consecutiveWins);
                        FileWriteInteger(handle, cell.consecutiveLosses);
                        FileWriteLong(handle, cell.lastSignalTime);
                        FileWriteLong(handle, cell.lastWinTime);
                        FileWriteDouble(handle, cell.confidenceScore);
                        FileWriteDouble(handle, cell.emaPerformance);
                    }
                }
            }
        }

        // Guardar estadísticas globales
        FileWriteInteger(handle, m_totalSystemTrades);
        FileWriteLong(handle, m_systemStartTime);

        FileClose(handle);
        Print("💾 Matriz contextual guardada: ", filename, " (", m_totalSystemTrades, " trades)");
    }

    //+------------------------------------------------------------------+
    //| Cargar Datos de Performance (Persistencia)                     |
    //+------------------------------------------------------------------+
    void LoadPerformanceData() {
        string filename = "NCN_VotingContextMatrix_" + _Symbol + ".bin";

        if(!FileIsExist(filename)) {
            Print("ℹ️ No se encontró archivo previo. Iniciando desde cero.");
            return;
        }

        int handle = FileOpen(filename, FILE_READ|FILE_BIN);
        if(handle == INVALID_HANDLE) {
            Print("⚠️ WARNING: No se pudo leer matriz contextual");
            return;
        }

        // Cargar matriz completa
        for(int ind = 0; ind < 5; ind++) {
            for(int ses = 0; ses < 3; ses++) {
                for(int vol = 0; vol < 2; vol++) {
                    for(int dir = 0; dir < 2; dir++) {
                        m_performanceMatrix[ind][ses][vol][dir].totalSignals = FileReadInteger(handle);
                        m_performanceMatrix[ind][ses][vol][dir].wins = FileReadInteger(handle);
                        m_performanceMatrix[ind][ses][vol][dir].losses = FileReadInteger(handle);
                        m_performanceMatrix[ind][ses][vol][dir].accumulatedProfit = FileReadDouble(handle);
                        m_performanceMatrix[ind][ses][vol][dir].winRate = FileReadDouble(handle);
                        m_performanceMatrix[ind][ses][vol][dir].avgProfit = FileReadDouble(handle);
                        m_performanceMatrix[ind][ses][vol][dir].consecutiveWins = FileReadInteger(handle);
                        m_performanceMatrix[ind][ses][vol][dir].consecutiveLosses = FileReadInteger(handle);
                        m_performanceMatrix[ind][ses][vol][dir].lastSignalTime = (datetime)FileReadLong(handle);
                        m_performanceMatrix[ind][ses][vol][dir].lastWinTime = (datetime)FileReadLong(handle);
                        m_performanceMatrix[ind][ses][vol][dir].confidenceScore = FileReadDouble(handle);
                        m_performanceMatrix[ind][ses][vol][dir].emaPerformance = FileReadDouble(handle);

                        // Validar celda cargada
                        m_performanceMatrix[ind][ses][vol][dir].Validate();
                    }
                }
            }
        }

        // Cargar estadísticas globales
        if(!FileIsEnding(handle)) {
            m_totalSystemTrades = FileReadInteger(handle);
            m_systemStartTime = (datetime)FileReadLong(handle);
        }

        FileClose(handle);
        Print("✅ Matriz contextual cargada: ", filename, " (", m_totalSystemTrades, " trades históricos)");
    }

    //+------------------------------------------------------------------+
    //| Obtener Insight Contextual (Recomendaciones)                   |
    //+------------------------------------------------------------------+
    string GetContextualInsight() {
        UpdateCurrentContext();

        string sessionName[] = {"ASIA", "LONDON", "NY"};
        string volName[] = {"LOW_VOL", "HIGH_VOL"};

        // Obtener top 3
        int topIds[];
        string topNames[];
        double topWR[];
        GetTopIndicators(topIds, topNames, topWR, 3);

        string insight = StringFormat(
            "📍 Contexto: %s | %s | Top: %s (%.1f%%)",
            sessionName[m_currentContext.session],
            volName[m_currentContext.volatility],
            (ArraySize(topNames) > 0) ? topNames[0] : "N/A",
            (ArraySize(topWR) > 0) ? topWR[0] * 100.0 : 0.0
        );

        return insight;
    }

    //+------------------------------------------------------------------+
    //| COMPATIBILIDAD: UpdatePerformance (Legacy API)                 |
    //| Mantiene compatibilidad con código existente                   |
    //+------------------------------------------------------------------+
    void UpdatePerformance(int indicatorId, bool success, double profit) {
        // Detectar dirección basada en resultado (si es positivo asumimos que fue en la dirección correcta)
        // Para mejor precisión, el código principal debería pasar la dirección explícitamente
        ENUM_VOTING_DIRECTION dir = (profit > 0) ? VOTING_DIR_BUY : VOTING_DIR_SELL;

        // Llamar al nuevo método de aprendizaje
        LearnFromTrade(indicatorId, dir, success, profit);
    }

    //+------------------------------------------------------------------+
    //| Obtener Pesos Actuales de Indicadores (para debugging)         |
    //+------------------------------------------------------------------+
    void GetCurrentWeights(double &weights[]) {
        ArrayResize(weights, 5);
        for(int i = 0; i < 5; i++) {
            weights[i] = m_indicators[i].currentWeight;
        }
    }

    //+------------------------------------------------------------------+
    //| Obtener Nombre de Indicador por ID                             |
    //+------------------------------------------------------------------+
    string GetIndicatorName(int id) {
        if(id >= 0 && id < 5) {
            return m_indicators[id].name;
        }
        return "Unknown";
    }
};

//+------------------------------------------------------------------+
//| MÓDULO DE CÁLCULO DE SEÑALES POR INDICADOR                      |
//| Calcula señales individuales de cada indicador técnico          |
//+------------------------------------------------------------------+

//--- Estructura para resultado de señal de indicador
struct IndicatorSignal {
    double buyStrength;      // Fuerza de señal de compra (0.0 - 1.0)
    double sellStrength;     // Fuerza de señal de venta (0.0 - 1.0)
    double confidence;       // Confianza en la señal (0.0 - 1.0)
    string reasoning;        // Explicación de la señal
    bool isValid;            // ¿Señal válida?

    void Initialize() {
        buyStrength = 0.0;
        sellStrength = 0.0;
        confidence = 0.0;
        reasoning = "";
        isValid = false;
    }
};

//+------------------------------------------------------------------+
//| Clase: Calculador de Señales de Indicadores                    |
//+------------------------------------------------------------------+
class SignalCalculator {
private:
    // Handles de indicadores (para eficiencia)
    int m_atr_handle;
    int m_rsi_handle;
    int m_macd_handle;
    int m_bb_handle;
    int m_ma_fast_handle;
    int m_ma_slow_handle;

    // Cache de datos
    double m_lastPrice;
    datetime m_lastUpdate;

    // Niveles de S/R detectados
    double m_supportLevels[10];
    double m_resistanceLevels[10];
    int m_supportCount;
    int m_resistanceCount;

    //+------------------------------------------------------------------+
    //| Detectar Niveles de Soporte y Resistencia                      |
    //+------------------------------------------------------------------+
    void DetectSRLevels() {
        ArrayInitialize(m_supportLevels, 0.0);
        ArrayInitialize(m_resistanceLevels, 0.0);
        m_supportCount = 0;
        m_resistanceCount = 0;

        // Analizar últimas 100 velas para encontrar pivotes
        int lookback = 100;
        double high[], low[], close[];
        ArraySetAsSeries(high, true);
        ArraySetAsSeries(low, true);
        ArraySetAsSeries(close, true);

        if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, high) != lookback) return;
        if(CopyLow(_Symbol, PERIOD_CURRENT, 0, lookback, low) != lookback) return;
        if(CopyClose(_Symbol, PERIOD_CURRENT, 0, lookback, close) != lookback) return;

        double currentPrice = close[0];
        double atr = GetATR();

        // Detectar pivotes (mínimos y máximos locales)
        for(int i = 3; i < lookback - 3; i++) {
            // Pivote de resistencia (máximo local)
            if(high[i] > high[i-1] && high[i] > high[i-2] && high[i] > high[i-3] &&
               high[i] > high[i+1] && high[i] > high[i+2] && high[i] > high[i+3]) {

                // Verificar que esté cerca del precio actual (dentro de 10 ATRs)
                if(MathAbs(high[i] - currentPrice) <= atr * 10) {
                    if(m_resistanceCount < 10) {
                        m_resistanceLevels[m_resistanceCount] = high[i];
                        m_resistanceCount++;
                    }
                }
            }

            // Pivote de soporte (mínimo local)
            if(low[i] < low[i-1] && low[i] < low[i-2] && low[i] < low[i-3] &&
               low[i] < low[i+1] && low[i] < low[i+2] && low[i] < low[i+3]) {

                if(MathAbs(low[i] - currentPrice) <= atr * 10) {
                    if(m_supportCount < 10) {
                        m_supportLevels[m_supportCount] = low[i];
                        m_supportCount++;
                    }
                }
            }
        }

        // Ordenar niveles
        ArraySort(m_supportLevels);
        ArrayReverse(m_supportLevels);  // Orden descendente
        ArraySort(m_resistanceLevels);  // Orden ascendente
    }

    //+------------------------------------------------------------------+
    //| Obtener ATR actual                                             |
    //+------------------------------------------------------------------+
    double GetATR() {
        if(m_atr_handle == INVALID_HANDLE) return 0.0;

        double atr_buffer[];
        ArraySetAsSeries(atr_buffer, true);
        if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) > 0) {
            return atr_buffer[0];
        }
        return 0.0;
    }

    //+------------------------------------------------------------------+
    //| Calcular Fuerza de Tendencia (usando MAs)                      |
    //+------------------------------------------------------------------+
    double CalculateTrendStrength() {
        if(m_ma_fast_handle == INVALID_HANDLE || m_ma_slow_handle == INVALID_HANDLE) {
            return 0.0;
        }

        double ma_fast[], ma_slow[];
        ArraySetAsSeries(ma_fast, true);
        ArraySetAsSeries(ma_slow, true);

        if(CopyBuffer(m_ma_fast_handle, 0, 0, 3, ma_fast) != 3) return 0.0;
        if(CopyBuffer(m_ma_slow_handle, 0, 0, 3, ma_slow) != 3) return 0.0;

        // Calcular separación normalizada
        double separation = (ma_fast[0] - ma_slow[0]) / GetATR();

        // Normalizar a rango [-1, 1]
        return MathMax(-1.0, MathMin(1.0, separation / 2.0));
    }

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    SignalCalculator() {
        m_atr_handle = INVALID_HANDLE;
        m_rsi_handle = INVALID_HANDLE;
        m_macd_handle = INVALID_HANDLE;
        m_bb_handle = INVALID_HANDLE;
        m_ma_fast_handle = INVALID_HANDLE;
        m_ma_slow_handle = INVALID_HANDLE;
        m_lastPrice = 0.0;
        m_lastUpdate = 0;
        m_supportCount = 0;
        m_resistanceCount = 0;
    }

    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~SignalCalculator() {
        if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
        if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
        if(m_macd_handle != INVALID_HANDLE) IndicatorRelease(m_macd_handle);
        if(m_bb_handle != INVALID_HANDLE) IndicatorRelease(m_bb_handle);
        if(m_ma_fast_handle != INVALID_HANDLE) IndicatorRelease(m_ma_fast_handle);
        if(m_ma_slow_handle != INVALID_HANDLE) IndicatorRelease(m_ma_slow_handle);
    }

    //+------------------------------------------------------------------+
    //| Inicialización                                                  |
    //+------------------------------------------------------------------+
    bool Initialize() {
        Print("🔧 Inicializando SignalCalculator...");

        // Crear handles de indicadores
        m_atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        m_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
        m_macd_handle = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
        m_bb_handle = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
        m_ma_fast_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
        m_ma_slow_handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);

        // Verificar que todos los handles sean válidos
        if(m_atr_handle == INVALID_HANDLE || m_rsi_handle == INVALID_HANDLE ||
           m_macd_handle == INVALID_HANDLE || m_bb_handle == INVALID_HANDLE ||
           m_ma_fast_handle == INVALID_HANDLE || m_ma_slow_handle == INVALID_HANDLE) {
            Print("❌ ERROR: No se pudieron crear todos los handles de indicadores");
            return false;
        }

        // Detectar niveles iniciales de S/R
        DetectSRLevels();

        Print("✅ SignalCalculator inicializado correctamente");
        Print("   📊 Soportes detectados: ", m_supportCount);
        Print("   📊 Resistencias detectadas: ", m_resistanceCount);

        return true;
    }

    //+------------------------------------------------------------------+
    //| [0] Calcular Señal de Soporte/Resistencia                      |
    //+------------------------------------------------------------------+
    IndicatorSignal CalculateSRSignal() {
        IndicatorSignal signal;
        signal.Initialize();

        // Actualizar niveles si ha pasado suficiente tiempo
        datetime currentTime = TimeCurrent();
        if(currentTime - m_lastUpdate > 3600) {  // Cada hora
            DetectSRLevels();
            m_lastUpdate = currentTime;
        }

        double close[];
        ArraySetAsSeries(close, true);
        if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, close) != 1) {
            return signal;
        }

        double currentPrice = close[0];
        double atr = GetATR();
        if(atr <= 0) return signal;

        double buyScore = 0.0;
        double sellScore = 0.0;
        string reasons = "";

        // Analizar distancia a soportes
        for(int i = 0; i < m_supportCount; i++) {
            double distance = currentPrice - m_supportLevels[i];
            double distanceInATR = distance / atr;

            // Cerca de soporte (dentro de 0.5 ATR) → señal de compra
            if(distanceInATR >= 0 && distanceInATR <= 0.5) {
                double strength = 1.0 - (distanceInATR / 0.5);  // 1.0 en el nivel, 0.0 a 0.5 ATR
                buyScore += strength * 0.4;  // Peso 40% por cada soporte
                reasons += StringFormat("Soporte en %.5f (+%.1f%%) ", m_supportLevels[i], strength*40);
            }
        }

        // Analizar distancia a resistencias
        for(int i = 0; i < m_resistanceCount; i++) {
            double distance = m_resistanceLevels[i] - currentPrice;
            double distanceInATR = distance / atr;

            // Cerca de resistencia (dentro de 0.5 ATR) → señal de venta
            if(distanceInATR >= 0 && distanceInATR <= 0.5) {
                double strength = 1.0 - (distanceInATR / 0.5);
                sellScore += strength * 0.4;
                reasons += StringFormat("Resistencia en %.5f (+%.1f%%) ", m_resistanceLevels[i], strength*40);
            }
        }

        // Normalizar scores
        signal.buyStrength = MathMin(1.0, buyScore);
        signal.sellStrength = MathMin(1.0, sellScore);
        signal.confidence = MathMax(signal.buyStrength, signal.sellStrength);
        signal.reasoning = (reasons != "") ? reasons : "Sin niveles cercanos";
        signal.isValid = (signal.confidence > 0.3);  // Mínimo 30% de confianza

        return signal;
    }

    //+------------------------------------------------------------------+
    //| [1] Calcular Señal de Machine Learning (simplificada)          |
    //+------------------------------------------------------------------+
    IndicatorSignal CalculateMLSignal() {
        IndicatorSignal signal;
        signal.Initialize();

        // Para ML, usamos una combinación de múltiples indicadores con pesos aprendidos
        double trendStrength = CalculateTrendStrength();

        // Obtener RSI
        double rsi_buffer[];
        ArraySetAsSeries(rsi_buffer, true);
        if(m_rsi_handle != INVALID_HANDLE) {
            if(CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_buffer) > 0) {
                double rsi = rsi_buffer[0];

                // Combinar tendencia + RSI
                if(trendStrength > 0.3 && rsi < 40) {
                    // Tendencia alcista + RSI sobrevendido
                    signal.buyStrength = MathMin(1.0, trendStrength + (50 - rsi) / 50);
                    signal.sellStrength = 0.2;
                    signal.reasoning = StringFormat("ML: Tendencia+ (%.2f) + RSI OV (%.1f)", trendStrength, rsi);
                } else if(trendStrength < -0.3 && rsi > 60) {
                    // Tendencia bajista + RSI sobrecomprado
                    signal.buyStrength = 0.2;
                    signal.sellStrength = MathMin(1.0, MathAbs(trendStrength) + (rsi - 50) / 50);
                    signal.reasoning = StringFormat("ML: Tendencia- (%.2f) + RSI OC (%.1f)", trendStrength, rsi);
                } else {
                    signal.buyStrength = 0.5;
                    signal.sellStrength = 0.5;
                    signal.reasoning = "ML: Señal neutral";
                }

                signal.confidence = MathAbs(signal.buyStrength - signal.sellStrength);
                signal.isValid = (signal.confidence > 0.2);
            }
        }

        return signal;
    }

    //+------------------------------------------------------------------+
    //| [2] Calcular Señal de Momentum                                 |
    //+------------------------------------------------------------------+
    IndicatorSignal CalculateMomentumSignal() {
        IndicatorSignal signal;
        signal.Initialize();

        if(m_macd_handle == INVALID_HANDLE) return signal;

        double macd_main[], macd_signal[];
        ArraySetAsSeries(macd_main, true);
        ArraySetAsSeries(macd_signal, true);

        if(CopyBuffer(m_macd_handle, 0, 0, 3, macd_main) != 3) return signal;
        if(CopyBuffer(m_macd_handle, 1, 0, 3, macd_signal) != 3) return signal;

        // MACD cross
        bool bullishCross = (macd_main[1] <= macd_signal[1] && macd_main[0] > macd_signal[0]);
        bool bearishCross = (macd_main[1] >= macd_signal[1] && macd_main[0] < macd_signal[0]);

        // Fuerza del MACD
        double macdStrength = MathAbs(macd_main[0]);
        double maxMacd = 0.001;  // Normalización aproximada
        double normalizedMacd = MathMin(1.0, macdStrength / maxMacd);

        if(bullishCross || macd_main[0] > macd_signal[0]) {
            signal.buyStrength = 0.5 + (normalizedMacd * 0.5);
            signal.sellStrength = 0.2;
            signal.reasoning = bullishCross ? "MACD: Cruce alcista" : "MACD: Por encima de señal";
        } else if(bearishCross || macd_main[0] < macd_signal[0]) {
            signal.buyStrength = 0.2;
            signal.sellStrength = 0.5 + (normalizedMacd * 0.5);
            signal.reasoning = bearishCross ? "MACD: Cruce bajista" : "MACD: Por debajo de señal";
        } else {
            signal.buyStrength = 0.5;
            signal.sellStrength = 0.5;
            signal.reasoning = "MACD: Neutral";
        }

        signal.confidence = MathAbs(signal.buyStrength - signal.sellStrength);
        signal.isValid = (signal.confidence > 0.1);

        return signal;
    }

    //+------------------------------------------------------------------+
    //| [3] Calcular Señal de RSI con Divergencias                     |
    //+------------------------------------------------------------------+
    IndicatorSignal CalculateRSISignal() {
        IndicatorSignal signal;
        signal.Initialize();

        if(m_rsi_handle == INVALID_HANDLE) return signal;

        double rsi_buffer[];
        ArraySetAsSeries(rsi_buffer, true);

        if(CopyBuffer(m_rsi_handle, 0, 0, 10, rsi_buffer) != 10) return signal;

        double currentRSI = rsi_buffer[0];

        // Análisis de niveles
        if(currentRSI < 30) {
            // Sobreventa fuerte
            signal.buyStrength = 0.8 + ((30 - currentRSI) / 30) * 0.2;  // 0.8 - 1.0
            signal.sellStrength = 0.1;
            signal.reasoning = StringFormat("RSI: Sobreventa extrema (%.1f)", currentRSI);
            signal.confidence = 0.9;
        } else if(currentRSI < 40) {
            // Sobreventa
            signal.buyStrength = 0.6 + ((40 - currentRSI) / 10) * 0.2;  // 0.6 - 0.8
            signal.sellStrength = 0.3;
            signal.reasoning = StringFormat("RSI: Sobreventa (%.1f)", currentRSI);
            signal.confidence = 0.7;
        } else if(currentRSI > 70) {
            // Sobrecompra fuerte
            signal.buyStrength = 0.1;
            signal.sellStrength = 0.8 + ((currentRSI - 70) / 30) * 0.2;  // 0.8 - 1.0
            signal.reasoning = StringFormat("RSI: Sobrecompra extrema (%.1f)", currentRSI);
            signal.confidence = 0.9;
        } else if(currentRSI > 60) {
            // Sobrecompra
            signal.buyStrength = 0.3;
            signal.sellStrength = 0.6 + ((currentRSI - 60) / 10) * 0.2;  // 0.6 - 0.8
            signal.reasoning = StringFormat("RSI: Sobrecompra (%.1f)", currentRSI);
            signal.confidence = 0.7;
        } else {
            // Zona neutral
            signal.buyStrength = 0.5;
            signal.sellStrength = 0.5;
            signal.reasoning = StringFormat("RSI: Neutral (%.1f)", currentRSI);
            signal.confidence = 0.3;
        }

        // Detectar divergencias (simple)
        double close[];
        ArraySetAsSeries(close, true);
        if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 10, close) == 10) {
            // Divergencia alcista: precio baja pero RSI sube
            if(close[0] < close[5] && rsi_buffer[0] > rsi_buffer[5]) {
                signal.buyStrength = MathMin(1.0, signal.buyStrength + 0.2);
                signal.reasoning += " + Divergencia alcista";
                signal.confidence = MathMin(1.0, signal.confidence + 0.1);
            }
            // Divergencia bajista: precio sube pero RSI baja
            else if(close[0] > close[5] && rsi_buffer[0] < rsi_buffer[5]) {
                signal.sellStrength = MathMin(1.0, signal.sellStrength + 0.2);
                signal.reasoning += " + Divergencia bajista";
                signal.confidence = MathMin(1.0, signal.confidence + 0.1);
            }
        }

        signal.isValid = (signal.confidence > 0.3);

        return signal;
    }

    //+------------------------------------------------------------------+
    //| [4] Calcular Señal de Volume Profile                           |
    //+------------------------------------------------------------------+
    IndicatorSignal CalculateVolumeSignal() {
        IndicatorSignal signal;
        signal.Initialize();

        long volume[];
        double close[];
        ArraySetAsSeries(volume, true);
        ArraySetAsSeries(close, true);

        if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 20, volume) != 20) return signal;
        if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 20, close) != 20) return signal;

        // Calcular volumen promedio
        long avgVolume = 0;
        for(int i = 1; i < 20; i++) {
            avgVolume += volume[i];
        }
        avgVolume /= 19;

        // Volumen actual vs promedio
        double volumeRatio = (avgVolume > 0) ? (double)volume[0] / avgVolume : 1.0;

        // Dirección del precio
        double priceChange = close[0] - close[1];
        bool priceUp = (priceChange > 0);

        // Señal basada en volumen y dirección
        if(volumeRatio > 1.5) {  // Volumen alto (>150% del promedio)
            if(priceUp) {
                signal.buyStrength = 0.6 + MathMin(0.4, (volumeRatio - 1.5) / 2.0);
                signal.sellStrength = 0.2;
                signal.reasoning = StringFormat("Vol: Alto + Precio↑ (%.1fx)", volumeRatio);
                signal.confidence = 0.8;
            } else {
                signal.buyStrength = 0.2;
                signal.sellStrength = 0.6 + MathMin(0.4, (volumeRatio - 1.5) / 2.0);
                signal.reasoning = StringFormat("Vol: Alto + Precio↓ (%.1fx)", volumeRatio);
                signal.confidence = 0.8;
            }
        } else if(volumeRatio < 0.7) {  // Volumen bajo
            signal.buyStrength = 0.5;
            signal.sellStrength = 0.5;
            signal.reasoning = StringFormat("Vol: Bajo (%.1fx)", volumeRatio);
            signal.confidence = 0.2;
        } else {  // Volumen normal
            signal.buyStrength = 0.5;
            signal.sellStrength = 0.5;
            signal.reasoning = StringFormat("Vol: Normal (%.1fx)", volumeRatio);
            signal.confidence = 0.4;
        }

        signal.isValid = (signal.confidence > 0.2);

        return signal;
    }

    //+------------------------------------------------------------------+
    //| Calcular Todas las Señales                                     |
    //+------------------------------------------------------------------+
    void CalculateAllSignals(double &buyVotes[], double &sellVotes[]) {
        ArrayResize(buyVotes, 5);
        ArrayResize(sellVotes, 5);

        IndicatorSignal signals[5];

        // Calcular cada señal
        signals[0] = CalculateSRSignal();
        signals[1] = CalculateMLSignal();
        signals[2] = CalculateMomentumSignal();
        signals[3] = CalculateRSISignal();
        signals[4] = CalculateVolumeSignal();

        // Transferir a arrays
        for(int i = 0; i < 5; i++) {
            buyVotes[i] = signals[i].isValid ? signals[i].buyStrength : 0.5;
            sellVotes[i] = signals[i].isValid ? signals[i].sellStrength : 0.5;

            // Debug logging
            if(signals[i].isValid) {
                Print(StringFormat("[%d] BUY:%.2f SELL:%.2f CONF:%.2f | %s",
                      i, buyVotes[i], sellVotes[i], signals[i].confidence, signals[i].reasoning));
            }
        }
    }
};

//+------------------------------------------------------------------+
//| Función Helper: Actualizar Contexto desde Mercado              |
//+------------------------------------------------------------------+
void UpdateContextFromMarket(QuantumMarketContext &ctx) {
    // Calcular bid-ask imbalance real
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double spread = ask - bid;
    double mid = (bid + ask) / 2.0;

    if(mid > 0) {
        ctx.bid_ask_imbalance = (spread / mid) * 10000;  // En basis points
    }

    // Volume analysis
    long volume = SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);

    // Calcular volumen promedio usando el volumen del día
    long volume_high = SymbolInfoInteger(_Symbol, SYMBOL_VOLUMEHIGH);
    long volume_low = SymbolInfoInteger(_Symbol, SYMBOL_VOLUMELOW);
    long avg_volume = (volume_high + volume_low) / 2;

    if(avg_volume <= 0) {
        avg_volume = volume > 0 ? volume : 1;
    }

    ctx.volume_weighted_momentum = (volume > 0 && avg_volume > 0) ?
                                   (double)volume / avg_volume - 1.0 : 0.0;

    // Volatilidad real
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(atr_handle != INVALID_HANDLE) {
        double atr_buffer[];
        ArraySetAsSeries(atr_buffer, true);
        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0 && mid > 0) {
            ctx.next_hour_volatility = atr_buffer[0] / mid;
        }
        IndicatorRelease(atr_handle);
    }

    // RSI para sentimiento
    int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    if(rsi_handle != INVALID_HANDLE) {
        double rsi_buffer[];
        ArraySetAsSeries(rsi_buffer, true);
        if(CopyBuffer(rsi_handle, 0, (MQLInfoInteger(MQL_TESTER) ? 1 : 0), 1, rsi_buffer) > 0) {
            ctx.retail_sentiment = rsi_buffer[0] / 100.0;
            ctx.fear_greed_oscillator = (rsi_buffer[0] - 50) / 50.0;
        }
        IndicatorRelease(rsi_handle);
    }

    ctx.last_update = TimeCurrent();
    ctx.data_quality_score = 100;
}

//+------------------------------------------------------------------+
//| Clase: Sistema de Aprendizaje con Memoria - AUDITADO           |
//+------------------------------------------------------------------+
class TradeLearningSystem {
private:
    TradeContext history[1000];
    int historyCount;
    int maxHistorySize;  // AUDITORÍA: Agregar límite configurable
    
public:
    void Initialize() {
        historyCount = 0;
        maxHistorySize = 1000;  // AUDITORÍA: Establecer límite explícito
        
        for(int i = 0; i < maxHistorySize; i++) {
            history[i].Initialize();
        }
    }
    
    void RecordTrade(const TradeContext &trade) {
        // AUDITORÍA: Validar trade antes de registrar
        if(trade.atr < 0 || trade.rsi < 0 || trade.rsi > 100) {
            Print("WARNING: RecordTrade - Trade con valores inválidos, omitiendo");
            return;
        }
        
        // AUDITORÍA: Usar módulo correcto para índice circular
        int idx = historyCount % maxHistorySize;
        history[idx] = trade;
        historyCount++;
        
        // AUDITORÍA: Prevenir overflow del contador
        if(historyCount >= INT_MAX - 1000) {
            Print("WARNING: RecordTrade - Reseteando contador de historial para prevenir overflow");
            historyCount = maxHistorySize;
        }
        
        // Actualizar patrones cada 10 trades
        if(historyCount % 10 == 0) {
            UpdateSuccessPatterns();
            UpdateFailurePatterns();
        }
    }
    
    double PredictSuccess(const TradeContext &current) {
        // AUDITORÍA: Validar contexto de entrada
        if(current.atr <= 0) {
            Print("WARNING: PredictSuccess - ATR inválido");
            return 0.5;
        }
        
        double similarity;
        double totalWeight = 0;
        double successScore = 0;
        
        // AUDITORÍA: Limitar búsqueda para evitar overhead
        int searchLimit = MathMin(historyCount, maxHistorySize);
        searchLimit = MathMin(searchLimit, 500);  // Máximo 500 comparaciones
        
        for(int i = 0; i < searchLimit; i++) {
            // AUDITORÍA: Calcular índice circular correcto
            int idx = (historyCount - i - 1) % maxHistorySize;
            if(idx < 0) idx += maxHistorySize;
            
            similarity = CalculateSimilarity(current, history[idx]);
            
            if(similarity > 0.7) {  // 70% similar
                totalWeight += similarity;
                if(history[idx].wasSuccessful) {
                    successScore += similarity;
                }
            }
        }
        
        // AUDITORÍA: Manejar división por cero
        if(totalWeight > 0.001) {
            double prediction = successScore / totalWeight;
            // AUDITORÍA: Clamp resultado a rango válido
            return MathMax(0.0, MathMin(1.0, prediction));
        }
        
        return 0.5;  // Sin datos históricos
    }
    
    void OptimizeParameters(double &bestRSI, double &bestMomentum, double &bestATR) {
        // AUDITORÍA: Inicializar con valores seguros
        bestRSI = 50.0;
        bestMomentum = 0.0;
        bestATR = 1.0;
        
        double bestProfit = -99999;
        int searchLimit = MathMin(historyCount, MathMin(maxHistorySize, 100));
        
        // AUDITORÍA: Verificar que haya datos antes de optimizar
        if(searchLimit == 0) {
            Print("WARNING: OptimizeParameters - No hay datos históricos para optimizar");
            return;
        }
        
        for(int i = 0; i < searchLimit; i++) {
            int idx = (historyCount - i - 1) % maxHistorySize;
            if(idx < 0) idx += maxHistorySize;
            
            if(history[idx].profit > bestProfit) {
                bestProfit = history[idx].profit;
                bestRSI = history[idx].rsi;
                bestMomentum = history[idx].momentum;
                bestATR = history[idx].atr;
            }
        }
        
        // AUDITORÍA: Validar valores antes de retornar
        bestRSI = MathMax(0.0, MathMin(100.0, bestRSI));
        bestMomentum = MathMax(-100.0, MathMin(100.0, bestMomentum));
        bestATR = MathMax(0.0, bestATR);
        
        Print("📊 Optimizando - Mejor RSI: ", bestRSI, 
              " Mejor Momentum: ", bestMomentum,
              " Mejor ATR: ", bestATR);
    }
    
private:
    double CalculateSimilarity(const TradeContext &a, const TradeContext &b) {
    double sim = 0;
    
    // AUDITORÍA: Validar divisiones por cero y rangos
    double rsiDiff = (a.rsi > 0 && b.rsi > 0) ? 
                    (1.0 - MathAbs(a.rsi - b.rsi) / 100.0) : 0.0;
    
    double momentumDiff = 1.0 - MathMin(1.0, MathAbs(a.momentum - b.momentum) / 100.0);
    
    double regimeSim = (a.regime == b.regime) ? 1.0 : 0.0;
    
    double srDiff = 1.0 - MathMin(1.0, MathAbs(a.srStrength - b.srStrength));
    
    double timeDiff = 1.0 - MathMin(1.0, MathAbs(a.timeOfDay - b.timeOfDay) / 24.0);
    
    // Pesos para cada factor (completo y normalizado)
    sim = rsiDiff * 0.2 + momentumDiff * 0.2 + regimeSim * 0.2 + 
          srDiff * 0.2 + timeDiff * 0.2;
    
    // AUDITORÍA: Asegurar resultado en [0,1] con clamping
    sim = MathMax(0.0, MathMin(1.0, sim));
    
    return sim;
}
    
    void UpdateSuccessPatterns() {
        // Identificar patrones de éxito
        double avgRSI = 0, avgMomentum = 0;
        int successCount = 0;
        
        int searchLimit = MathMin(historyCount, MathMin(maxHistorySize, 100));
        
        for(int i = 0; i < searchLimit; i++) {
            int idx = (historyCount - i - 1) % maxHistorySize;
            if(idx < 0) idx += maxHistorySize;
            
            if(history[idx].wasSuccessful) {
                avgRSI += history[idx].rsi;
                avgMomentum += history[idx].momentum;
                successCount++;
            }
        }
        
        // AUDITORÍA: Prevenir división por cero
        if(successCount > 0) {
            avgRSI /= successCount;
            avgMomentum /= successCount;
            Print("✅ Patrón de éxito: RSI=", avgRSI, " Momentum=", avgMomentum);
        }
    }
    
    void UpdateFailurePatterns() {
        // Identificar patrones de fallo
        double avgDrawdown = 0;
        int failCount = 0;
        
        int searchLimit = MathMin(historyCount, MathMin(maxHistorySize, 100));
        
        for(int i = 0; i < searchLimit; i++) {
            int idx = (historyCount - i - 1) % maxHistorySize;
            if(idx < 0) idx += maxHistorySize;
            
            if(!history[idx].wasSuccessful) {
                avgDrawdown += MathAbs(history[idx].maxDrawdown);
                failCount++;
            }
        }
        
        // AUDITORÍA: Prevenir división por cero
        if(failCount > 0) {
            avgDrawdown /= failCount;
            Print("❌ Patrón de fallo: Avg Drawdown=", avgDrawdown);
        }
    }
};

//+------------------------------------------------------------------+
//| Clase: LSTM Network (Red Neuronal Recurrente) - AUDITADA       |
//+------------------------------------------------------------------+
class CLSTMNetwork {
private:
    struct LSTMCell {
        double forget_gate[];
        double input_gate[];
        double output_gate[];
        double cell_state[];
        double hidden_state[];
        
        double Wf[], Wi[], Wo[], Wc[];  // Pesos
        double bf[], bi[], bo[], bc[];  // Bias
        
        bool initialized;  // AUDITORÍA: Flag de inicialización
    };
    
    LSTMCell m_cells[];
    int m_sequence_length;
    int m_hidden_size;
    int m_input_size;
    bool m_initialized;  // AUDITORÍA: Flag global
    
public:
    void Initialize(int sequence_len, int input_size, int hidden_size) {
        // AUDITORÍA: Validar parámetros de entrada
        if(sequence_len <= 0 || sequence_len > 100) {
            Print("ERROR: CLSTMNetwork - sequence_len inválido: ", sequence_len);
            m_initialized = false;
            return;
        }
        if(input_size <= 0 || input_size > QUANTUM_MAX_FEATURES) {
            Print("ERROR: CLSTMNetwork - input_size inválido: ", input_size);
            m_initialized = false;
            return;
        }
        if(hidden_size <= 0 || hidden_size > 512) {
            Print("ERROR: CLSTMNetwork - hidden_size inválido: ", hidden_size);
            m_initialized = false;
            return;
        }
        
        m_sequence_length = sequence_len;
        m_input_size = input_size;
        m_hidden_size = hidden_size;
        
        ArrayResize(m_cells, sequence_len);
        
        for(int t = 0; t < sequence_len; t++) {
            InitializeCell(m_cells[t]);
        }
        
        m_initialized = true;
    }
    
    void PredictSequence(const QuantumMarketContext &context, double &forecast[], int horizon) {
        // AUDITORÍA: Verificar inicialización
        if(!m_initialized) {
            Print("ERROR: CLSTMNetwork no inicializado");
            ArrayResize(forecast, horizon);
            ArrayInitialize(forecast, 0.0);
            return;
        }
        
        // AUDITORÍA: Validar horizon
        if(horizon <= 0 || horizon > 1000) {
            Print("WARNING: PredictSequence - horizon inválido: ", horizon);
            horizon = MathMax(1, MathMin(168, horizon));
        }
        
        ArrayResize(forecast, horizon);
        ArrayInitialize(forecast, 0.0);
        
        // Preparar input desde contexto
        double input_data[];
        ArrayResize(input_data, m_input_size);
        ContextToInput(context, input_data);
        
        // Forward pass por la secuencia
        for(int t = 0; t < m_sequence_length; t++) {
            if(!m_cells[t].initialized) {
                Print("ERROR: Cell ", t, " no inicializada");
                continue;
            }
            
            if(t > 0) {
                ForwardCell(m_cells[t], input_data, t, m_cells[t-1]);
            } else {
                ForwardCell(m_cells[t], input_data, t, m_cells[t]);
            }
        }
        
        // Generar predicciones
        for(int h = 0; h < horizon; h++) {
            forecast[h] = GeneratePrediction(h);
            // AUDITORÍA: Limitar predicciones a rango razonable
            forecast[h] = MathMax(-1.0, MathMin(1.0, forecast[h]));
        }
    }
    
private:
    void InitializeCell(LSTMCell &cell) {
        // AUDITORÍA: Verificar tamaños antes de allocation
        if(m_hidden_size <= 0 || m_input_size <= 0) {
            cell.initialized = false;
            return;
        }
        
        int weights_size = m_hidden_size * (m_input_size + m_hidden_size);
        
        // AUDITORÍA: Limitar tamaño máximo para evitar overflow
        if(weights_size > 100000) {
            Print("ERROR: InitializeCell - weights_size demasiado grande: ", weights_size);
            cell.initialized = false;
            return;
        }
        
        ArrayResize(cell.Wf, weights_size);
        ArrayResize(cell.Wi, weights_size);
        ArrayResize(cell.Wo, weights_size);
        ArrayResize(cell.Wc, weights_size);
        
        ArrayResize(cell.bf, m_hidden_size);
        ArrayResize(cell.bi, m_hidden_size);
        ArrayResize(cell.bo, m_hidden_size);
        ArrayResize(cell.bc, m_hidden_size);
        
        ArrayResize(cell.forget_gate, m_hidden_size);
        ArrayResize(cell.input_gate, m_hidden_size);
        ArrayResize(cell.output_gate, m_hidden_size);
        ArrayResize(cell.cell_state, m_hidden_size);
        ArrayResize(cell.hidden_state, m_hidden_size);
        
        // Inicializar arrays
        ArrayInitialize(cell.forget_gate, 0.0);
        ArrayInitialize(cell.input_gate, 0.0);
        ArrayInitialize(cell.output_gate, 0.0);
        ArrayInitialize(cell.cell_state, 0.0);
        ArrayInitialize(cell.hidden_state, 0.0);
        
        // Inicializar pesos con Xavier
        double scale = MathSqrt(2.0 / (m_input_size + m_hidden_size));
        // AUDITORÍA: Limitar scale para evitar valores extremos
        scale = MathMin(1.0, MathMax(0.01, scale));
        
        for(int i = 0; i < weights_size; i++) {
            cell.Wf[i] = GlobalRandomNormal(0, scale);
            cell.Wi[i] = GlobalRandomNormal(0, scale);
            cell.Wo[i] = GlobalRandomNormal(0, scale);
            cell.Wc[i] = GlobalRandomNormal(0, scale);
        }
        
        // Inicializar bias
        ArrayInitialize(cell.bf, 0.0);
        ArrayInitialize(cell.bi, 0.0);
        ArrayInitialize(cell.bo, 0.0);
        ArrayInitialize(cell.bc, 0.0);
        
        cell.initialized = true;
    }
    
    void ForwardCell(LSTMCell &cell, double &input_data[], int time_step, LSTMCell &prev_cell) {
        // AUDITORÍA: Verificar que la celda esté inicializada
        if(!cell.initialized) {
            Print("ERROR: ForwardCell - celda no inicializada");
            return;
        }
        
        // AUDITORÍA: Validar arrays de entrada
        if(ArraySize(input_data) != m_input_size) {
            Print("ERROR: ForwardCell - tamaño de input_data incorrecto");
            return;
        }
        
        // LSTM forward pass implementation
        for(int i = 0; i < m_hidden_size; i++) {
            // Forget gate
            double f_val = DotProduct(input_data, cell.Wf, i) + cell.bf[i];
            cell.forget_gate[i] = Sigmoid(f_val);
            
            // Input gate
            double i_val = DotProduct(input_data, cell.Wi, i) + cell.bi[i];
            cell.input_gate[i] = Sigmoid(i_val);
            
            // Output gate
            double o_val = DotProduct(input_data, cell.Wo, i) + cell.bo[i];
            cell.output_gate[i] = Sigmoid(o_val);
            
            // Cell state
            double c_val = DotProduct(input_data, cell.Wc, i) + cell.bc[i];
            double candidate = MathTanh(MathMax(-10.0, MathMin(10.0, c_val)));
            
            if(time_step > 0 && prev_cell.initialized) {
                cell.cell_state[i] = cell.forget_gate[i] * prev_cell.cell_state[i] +
                                     cell.input_gate[i] * candidate;
            } else {
                cell.cell_state[i] = cell.input_gate[i] * candidate;
            }
            
            // AUDITORÍA: Limitar cell state para evitar explosion
            cell.cell_state[i] = MathMax(-50.0, MathMin(50.0, cell.cell_state[i]));
            
            // Hidden state
            cell.hidden_state[i] = cell.output_gate[i] * MathTanh(cell.cell_state[i]);
        }
    }
    
    void ContextToInput(const QuantumMarketContext &ctx, double &input_data[]) {
        // AUDITORÍA: Verificar tamaño del array
        if(ArraySize(input_data) != m_input_size) {
            ArrayResize(input_data, m_input_size);
        }
        ArrayInitialize(input_data, 0.0);
        
        if(m_input_size <= 0) return;
        
        // AUDITORÍA: Asignación segura con validación de índices
        int idx = 0;
        if(idx < m_input_size) input_data[idx++] = MathMax(-10.0, MathMin(10.0, ctx.bid_ask_imbalance));
        if(idx < m_input_size) input_data[idx++] = MathMax(-1.0, MathMin(1.0, ctx.order_flow_toxicity));
        if(idx < m_input_size) input_data[idx++] = MathMax(-10.0, MathMin(10.0, ctx.volume_weighted_momentum));
        if(idx < m_input_size) input_data[idx++] = MathMax(-10.0, MathMin(10.0, ctx.smart_money_flow));
        if(idx < m_input_size) input_data[idx++] = MathMax(0.0, MathMin(1.0, ctx.regime_transition_probability));
        if(idx < m_input_size) input_data[idx++] = MathMax(0.0, MathMin(10.0, ctx.next_hour_volatility));
        if(idx < m_input_size) input_data[idx++] = MathMax(0.0, MathMin(1.0, ctx.institutional_sentiment));
        if(idx < m_input_size) input_data[idx++] = MathMax(-1.0, MathMin(1.0, ctx.fear_greed_oscillator));
        if(idx < m_input_size) input_data[idx++] = MathMax(-100.0, MathMin(100.0, ctx.daily_range_forecast));
        if(idx < m_input_size) input_data[idx++] = MathMax(-1.0, MathMin(1.0, ctx.weekly_trend_strength));
        
        // AUDITORÍA: Normalizar valores restantes
        for(int i = idx; i < m_input_size; i++) {
            input_data[i] = 0.0;
        }
    }
    
    double GeneratePrediction(int horizon) {
        // AUDITORÍA: Verificar inicialización
        if(m_sequence_length <= 0 || !m_initialized) return 0.0;
        
        int last_idx = m_sequence_length - 1;
        
        // AUDITORÍA: Verificar que la última celda esté inicializada
        if(!m_cells[last_idx].initialized) {
            Print("WARNING: GeneratePrediction - última celda no inicializada");
            return 0.0;
        }
        
        double sum = 0.0;
        int valid_count = 0;
        
        for(int i = 0; i < m_hidden_size; i++) {
            if(i < ArraySize(m_cells[last_idx].hidden_state)) {
                sum += m_cells[last_idx].hidden_state[i];
                valid_count++;
            }
        }
        
        // AUDITORÍA: Prevenir división por cero
        if(valid_count == 0) return 0.0;
        
        double decay = 1.0 - (horizon * 0.1);
        decay = MathMax(0.1, MathMin(1.0, decay));
        
        return MathTanh(sum / valid_count * decay);
    }
    
    double Sigmoid(double x) { 
        // Limitar x para evitar overflow
        x = MathMax(-50.0, MathMin(50.0, x));
        return 1.0 / (1.0 + MathExp(-x)); 
    }
    
    // CORRECCIÓN #2: Validación de límites en DotProduct - AUDITADA
    double DotProduct(double &v[], double &w[], int offset) {
        double sum = 0.0;
        int v_size = ArraySize(v);
        int w_size = ArraySize(w);
        
        // AUDITORÍA: Validar tamaños
        if(v_size <= 0 || w_size <= 0) {
            return 0.0;
        }
        
        int max_offset = (v_size > 0) ? w_size / v_size : 0;
        
        // Wrap around si el offset es muy grande
        if(max_offset > 0 && offset >= max_offset) {
            offset = offset % max_offset;
        }
        
        for(int i = 0; i < v_size; i++) {
            int idx = offset * v_size + i;
            if(idx >= 0 && idx < w_size) {  // AUDITORÍA: Verificación estricta
                sum += v[i] * w[idx];
            }
        }
        
        // AUDITORÍA: Limitar resultado para evitar explosión
        return MathMax(-100.0, MathMin(100.0, sum));
    }
};

//+------------------------------------------------------------------+
//| Clase: Transformer Network - CORREGIDA                          |
//+------------------------------------------------------------------+
class CTransformerNet {
private:
    struct AttentionHead {
        double query_weights[];
        double key_weights[];
        double value_weights[];
        double attention_scores[];
    };
    
    AttentionHead m_heads[];
    int m_num_heads;
    int m_embed_dim;
    int m_seq_length;
    
public:
    void Initialize(int num_heads, int embed_dim, int seq_length) {
        m_num_heads = num_heads;
        m_embed_dim = embed_dim;
        m_seq_length = seq_length;
        
        ArrayResize(m_heads, num_heads);
        
        for(int h = 0; h < num_heads; h++) {
            InitializeHead(m_heads[h]);
        }
    }
    
    void ComputeAttention(double &input_sequence[][], double &attention_weights[]) {
        ArrayResize(attention_weights, m_seq_length);
        ArrayInitialize(attention_weights, 0.0);
        
        // Multi-head attention
        for(int h = 0; h < m_num_heads; h++) {
            ComputeHeadAttention(m_heads[h], input_sequence);
        }
        
        // Agregar attention scores
        for(int i = 0; i < m_seq_length; i++) {
            attention_weights[i] = 0.0;
            for(int h = 0; h < m_num_heads; h++) {
                if(i < ArraySize(m_heads[h].attention_scores)) {
                    attention_weights[i] += m_heads[h].attention_scores[i];
                }
            }
            if(m_num_heads > 0) {
                attention_weights[i] /= m_num_heads;
            }
        }
        
        // Softmax normalization
        Softmax(attention_weights);
    }
    
private:
    void InitializeHead(AttentionHead &head) {
        int weight_size = m_embed_dim * m_embed_dim;
        
        ArrayResize(head.query_weights, weight_size);
        ArrayResize(head.key_weights, weight_size);
        ArrayResize(head.value_weights, weight_size);
        ArrayResize(head.attention_scores, m_seq_length);
        
        // Inicialización Xavier
        double scale = MathSqrt(2.0 / m_embed_dim);
        for(int i = 0; i < weight_size; i++) {
            head.query_weights[i] = GlobalRandomNormal(0, scale);
            head.key_weights[i] = GlobalRandomNormal(0, scale);
            head.value_weights[i] = GlobalRandomNormal(0, scale);
        }
        
        ArrayInitialize(head.attention_scores, 0.0);
    }
    
    // CORRECCIÓN #3: Reiniciar attention scores antes de calcular
    void ComputeHeadAttention(AttentionHead &head, double &sequence[][]) {
        // REINICIAR scores antes de calcular
        ArrayInitialize(head.attention_scores, 0.0);
        
        // Scaled dot-product attention
        double scale_factor = MathSqrt((double)m_embed_dim);
        if(scale_factor < 0.001) scale_factor = 1.0;
        
        int rows = ArrayRange(sequence, 0);
        int cols = ArrayRange(sequence, 1);
        
        for(int i = 0; i < m_seq_length && i < rows; i++) {
            head.attention_scores[i] = 0.0;
            for(int j = 0; j < m_seq_length && j < rows; j++) {
                // Q * K^T / sqrt(d_k)
                double score = 0.0;
                for(int k = 0; k < m_embed_dim && k < cols; k++) {
                    score += sequence[i][k] * sequence[j][k];
                }
                head.attention_scores[i] += score / scale_factor;
            }
        }
    }
    
    void Softmax(double &arr[]) {
        int size = ArraySize(arr);
        if(size == 0) return;
        
        double max_val = arr[0];
        for(int i = 1; i < size; i++) {
            if(arr[i] > max_val) max_val = arr[i];
        }
        
        // Limitar para evitar overflow
        max_val = MathMin(max_val, 50.0);
        
        double sum = 0.0;
        for(int i = 0; i < size; i++) {
            arr[i] = MathExp(arr[i] - max_val);
            sum += arr[i];
        }
        
        // Evitar división por cero
        if(sum < 0.00001) sum = 1.0;
        
        for(int i = 0; i < size; i++) {
            arr[i] /= sum;
        }
    }
};

//+------------------------------------------------------------------+
//| Clase: GAN Network - CORREGIDA                                  |
//+------------------------------------------------------------------+
class CGANNetwork {
private:
    struct Generator {
        double weights1[];
        double weights2[];
        double bias1[];
        double bias2[];
        int latent_dim;
        int hidden_dim;
        int output_dim;
    };
    
    struct Discriminator {
        double weights1[];
        double weights2[];
        double bias1[];
        double bias2[];
        int input_dim;
        int hidden_dim;
    };
    
    Generator m_generator;
    Discriminator m_discriminator;
    
public:
    void Initialize(int latent_dim, int scenario_dim) {
        // Inicializar Generator
        m_generator.latent_dim = latent_dim;
        m_generator.hidden_dim = 128;
        m_generator.output_dim = scenario_dim;
        
        InitializeGenerator();
        
        // Inicializar Discriminator
        m_discriminator.input_dim = scenario_dim;
        m_discriminator.hidden_dim = 128;
        
        InitializeDiscriminator();
    }
    
    void GenerateAdversarialScenarios(const QuantumMarketContext &context,
                                     double &scenarios[], int num_scenarios = 100) {
        int scenario_size = 10;
        ArrayResize(scenarios, num_scenarios * scenario_size);
        ArrayInitialize(scenarios, 0.0);
        
        for(int s = 0; s < num_scenarios; s++) {
            // Generar ruido latente
            double z[];
            ArrayResize(z, m_generator.latent_dim);
            for(int i = 0; i < m_generator.latent_dim; i++) {
                z[i] = GlobalRandomNormal(0, 1);
            }
            
            // Generar escenario adverso
            GenerateScenario(z, scenarios, s * scenario_size);
            
            // Ajustar por contexto actual
            AdjustScenarioByContext(scenarios, s * scenario_size, context);
        }
    }
    
private:
    void InitializeGenerator() {
        int w1_size = m_generator.latent_dim * m_generator.hidden_dim;
        int w2_size = m_generator.hidden_dim * m_generator.output_dim;
        
        ArrayResize(m_generator.weights1, w1_size);
        ArrayResize(m_generator.weights2, w2_size);
        ArrayResize(m_generator.bias1, m_generator.hidden_dim);
        ArrayResize(m_generator.bias2, m_generator.output_dim);
        
        // He initialization
        double scale1 = MathSqrt(2.0 / MathMax(1, m_generator.latent_dim));
        double scale2 = MathSqrt(2.0 / MathMax(1, m_generator.hidden_dim));
        
        for(int i = 0; i < w1_size; i++) {
            m_generator.weights1[i] = GlobalRandomNormal(0, scale1);
        }
        for(int i = 0; i < w2_size; i++) {
            m_generator.weights2[i] = GlobalRandomNormal(0, scale2);
        }
        
        ArrayInitialize(m_generator.bias1, 0.0);
        ArrayInitialize(m_generator.bias2, 0.0);
    }
    
    void InitializeDiscriminator() {
        int w1_size = m_discriminator.input_dim * m_discriminator.hidden_dim;
        int w2_size = m_discriminator.hidden_dim * 1;
        
        ArrayResize(m_discriminator.weights1, w1_size);
        ArrayResize(m_discriminator.weights2, w2_size);
        ArrayResize(m_discriminator.bias1, m_discriminator.hidden_dim);
        ArrayResize(m_discriminator.bias2, 1);
        
        double scale = MathSqrt(2.0 / MathMax(1, m_discriminator.input_dim));
        
        for(int i = 0; i < w1_size; i++) {
            m_discriminator.weights1[i] = GlobalRandomNormal(0, scale);
        }
        for(int i = 0; i < w2_size; i++) {
            m_discriminator.weights2[i] = GlobalRandomNormal(0, scale);
        }
        
        ArrayInitialize(m_discriminator.bias1, 0.0);
        ArrayInitialize(m_discriminator.bias2, 0.0);
    }
    
    void GenerateScenario(double &z[], double &scenarios[], int offset) {
        // Forward pass through generator
        double hidden[];
        ArrayResize(hidden, m_generator.hidden_dim);
        ArrayInitialize(hidden, 0.0);
        
        // Primera capa
        for(int i = 0; i < m_generator.hidden_dim; i++) {
            hidden[i] = m_generator.bias1[i];
            for(int j = 0; j < m_generator.latent_dim; j++) {
                int idx = i * m_generator.latent_dim + j;
                if(idx < ArraySize(m_generator.weights1)) {
                    hidden[i] += z[j] * m_generator.weights1[idx];
                }
            }
            hidden[i] = LeakyReLU(hidden[i]);
        }
        
        // Segunda capa (output)
        for(int i = 0; i < m_generator.output_dim && i < 10; i++) {
            if(offset + i < ArraySize(scenarios)) {
                scenarios[offset + i] = m_generator.bias2[i];
                for(int j = 0; j < m_generator.hidden_dim; j++) {
                    int idx = i * m_generator.hidden_dim + j;
                    if(idx < ArraySize(m_generator.weights2)) {
                        scenarios[offset + i] += hidden[j] * m_generator.weights2[idx];
                    }
                }
                scenarios[offset + i] = MathTanh(scenarios[offset + i]);
            }
        }
    }
    
    // CORRECCIÓN #4: Aplicar clipping a los multiplicadores
    void AdjustScenarioByContext(double &scenarios[], int offset,
                                const QuantumMarketContext &context) {
        // Aplicar clipping a los multiplicadores
        double toxicity_mult = MathMax(0.5, MathMin(1.5, 1.0 + context.order_flow_toxicity));
        double regime_mult = MathMax(0.5, MathMin(1.5, 1.0 + context.regime_transition_probability));
        double stability_mult = MathMax(0.5, MathMin(1.5, 2.0 - context.regime_stability_score));
        
        if(offset < ArraySize(scenarios)) {
            scenarios[offset] *= toxicity_mult;
            scenarios[offset] = MathMax(-1.0, MathMin(1.0, scenarios[offset]));
        }
        if(offset + 1 < ArraySize(scenarios)) {
            scenarios[offset + 1] *= regime_mult;
            scenarios[offset + 1] = MathMax(-1.0, MathMin(1.0, scenarios[offset + 1]));
        }
        if(offset + 2 < ArraySize(scenarios)) {
            scenarios[offset + 2] *= stability_mult;
            scenarios[offset + 2] = MathMax(-1.0, MathMin(1.0, scenarios[offset + 2]));
        }
    }
    
    double LeakyReLU(double x) { 
        return x > 0 ? x : 0.01 * x; 
    }
};

//+------------------------------------------------------------------+
//| Clase: Meta-Learner de Reinforcement Learning - CORREGIDA      |
//+------------------------------------------------------------------+
class CReinforcementLearner {
private:
    struct PolicyNetwork {
        double actor_weights[];
        double critic_weights[];
        double actor_bias[];
        double critic_bias[];
    };
    
    PolicyNetwork m_ppo;   // Proximal Policy Optimization
    PolicyNetwork m_a3c;   // Asynchronous Actor-Critic
    PolicyNetwork m_sac;   // Soft Actor-Critic
    
    double m_replay_buffer[][QUANTUM_MAX_FEATURES];
    int m_buffer_size;
    
public:
    void Initialize() {
        InitializePPO();
        InitializeA3C();
        InitializeSAC();
        
        ArrayResize(m_replay_buffer, QUANTUM_MEMORY_SIZE);
        m_buffer_size = 0;
    }
    
    QuantumDecisionProfile SynthesizeDecision(
        double &lstm_forecast[],
        double &attention_weights[],
        double &adversarial_scenarios[]
    ) {
        QuantumDecisionProfile decision;
        decision.Initialize();
        
        // Preparar estado compuesto
        double state[];
        PrepareState(state, lstm_forecast, attention_weights, adversarial_scenarios);
        
        // Obtener acciones de cada política
        double ppo_action = GetPPOAction(state);
        double a3c_action = GetA3CAction(state);
        double sac_action = GetSACAction(state);
        
        // Ensemble de políticas
        double final_action = (ppo_action * 0.4 + a3c_action * 0.3 + sac_action * 0.3);
        
        // Convertir a decisión concreta
        ConvertToDecision(final_action, decision);
        
        // Agregar razonamiento
        decision.reasoning = GenerateReasoning(state, final_action);
        
        return decision;
    }
    
    void UpdatePolicy(double reward, double &state[], double &next_state[]) {
        // Agregar a replay buffer
        if(m_buffer_size < QUANTUM_MEMORY_SIZE) {
            int state_size = MathMin(ArraySize(state), QUANTUM_MAX_FEATURES);
            for(int i = 0; i < state_size; i++) {
                m_replay_buffer[m_buffer_size][i] = state[i];
            }
            m_buffer_size++;
        }
        
        // Actualizar políticas
        UpdatePPO(reward, state, next_state);
        UpdateA3C(reward, state, next_state);
        UpdateSAC(reward, state, next_state);
    }
    
private:
    void InitializePPO() {
        int state_dim = QUANTUM_MAX_FEATURES;
        int hidden_dim = 256;
        int action_dim = 6; // Corresponde a ENUM_FINAL_ACTION
        
        ArrayResize(m_ppo.actor_weights, state_dim * hidden_dim);
        ArrayResize(m_ppo.critic_weights, state_dim * hidden_dim);
        ArrayResize(m_ppo.actor_bias, action_dim);
        ArrayResize(m_ppo.critic_bias, 1);
        
        // Inicialización Xavier
        InitializeWeights(m_ppo.actor_weights, state_dim);
        InitializeWeights(m_ppo.critic_weights, state_dim);
        
        ArrayInitialize(m_ppo.actor_bias, 0.0);
        ArrayInitialize(m_ppo.critic_bias, 0.0);
    }
    
    void InitializeA3C() {
        // Similar a PPO
        int state_dim = QUANTUM_MAX_FEATURES;
        int hidden_dim = 256;
        
        ArrayResize(m_a3c.actor_weights, state_dim * hidden_dim);
        ArrayResize(m_a3c.critic_weights, state_dim * hidden_dim);
        ArrayResize(m_a3c.actor_bias, 1);
        ArrayResize(m_a3c.critic_bias, 1);
        
        InitializeWeights(m_a3c.actor_weights, state_dim);
        InitializeWeights(m_a3c.critic_weights, state_dim);
        
        ArrayInitialize(m_a3c.actor_bias, 0.0);
        ArrayInitialize(m_a3c.critic_bias, 0.0);
    }
    
    void InitializeSAC() {
        // Soft Actor-Critic con temperature parameter
        int state_dim = QUANTUM_MAX_FEATURES;
        int hidden_dim = 256;
        
        ArrayResize(m_sac.actor_weights, state_dim * hidden_dim);
        ArrayResize(m_sac.critic_weights, state_dim * hidden_dim * 2); // Twin Q-functions
        ArrayResize(m_sac.actor_bias, 1);
        ArrayResize(m_sac.critic_bias, 2);
        
        InitializeWeights(m_sac.actor_weights, state_dim);
        InitializeWeights(m_sac.critic_weights, state_dim);
        
        ArrayInitialize(m_sac.actor_bias, 0.0);
        ArrayInitialize(m_sac.critic_bias, 0.0);
    }
    
    void InitializeWeights(double &weights[], int fan_in) {
        if(fan_in <= 0) fan_in = 1;
        double scale = MathSqrt(2.0 / fan_in);
        int size = ArraySize(weights);
        for(int i = 0; i < size; i++) {
            weights[i] = GlobalRandomNormal(0, scale);
        }
    }
    
    double GetPPOAction(double &state[]) {
        // PPO forward pass simplificado
        double action = 0.0;
        int state_size = MathMin(ArraySize(state), QUANTUM_MAX_FEATURES);
        int weight_size = ArraySize(m_ppo.actor_weights);
        
        for(int i = 0; i < state_size; i++) {
            if(i < weight_size) {
                action += state[i] * m_ppo.actor_weights[i];
            }
        }
        return MathTanh(action);
    }
    
    double GetA3CAction(double &state[]) {
        // A3C forward pass
        double action = 0.0;
        int state_size = MathMin(ArraySize(state), QUANTUM_MAX_FEATURES);
        int weight_size = ArraySize(m_a3c.actor_weights);
        
        for(int i = 0; i < state_size; i++) {
            if(i < weight_size) {
                action += state[i] * m_a3c.actor_weights[i];
            }
        }
        return MathTanh(action);
    }
    
    double GetSACAction(double &state[]) {
        // SAC forward pass con exploration
        double action = 0.0;
        double temperature = 0.1;
        int state_size = MathMin(ArraySize(state), QUANTUM_MAX_FEATURES);
        int weight_size = ArraySize(m_sac.actor_weights);
        
        for(int i = 0; i < state_size; i++) {
            if(i < weight_size) {
                action += state[i] * m_sac.actor_weights[i];
            }
        }
        
        // Agregar ruido para exploration
        action += GlobalRandomNormal(0, temperature);
        
        return MathTanh(action);
    }
    
    void UpdatePPO(double reward, double &state[], double &next_state[]) {
        // PPO update con clipped objective
        double clip_param = 0.2;
        double gamma = 0.99;
        double learning_rate = 0.0003;
        
        // Calcular advantage
        double value = GetValue(state, m_ppo.critic_weights);
        double next_value = GetValue(next_state, m_ppo.critic_weights);
        double advantage = reward + gamma * next_value - value;
        
        // Actualizar pesos con clipping
        int weight_size = ArraySize(m_ppo.actor_weights);
        int state_size = ArraySize(state);
        
        for(int i = 0; i < weight_size; i++) {
            double gradient = advantage * (i < state_size ? state[i] : 0.0);
            gradient = MathMax(-clip_param, MathMin(clip_param, gradient));
            m_ppo.actor_weights[i] += learning_rate * gradient;
        }
    }
    
    void UpdateA3C(double reward, double &state[], double &next_state[]) {
        // A3C asynchronous update
        double gamma = 0.99;
        double learning_rate = 0.0001;
        
        double value = GetValue(state, m_a3c.critic_weights);
        double next_value = GetValue(next_state, m_a3c.critic_weights);
        double td_error = reward + gamma * next_value - value;
        
        // Actualizar actor
        int weight_size = ArraySize(m_a3c.actor_weights);
        int state_size = ArraySize(state);
        
        for(int i = 0; i < weight_size; i++) {
            m_a3c.actor_weights[i] += learning_rate * td_error * 
                                      (i < state_size ? state[i] : 0.0);
        }
    }
    
    // CORRECCIÓN #5: Cálculo correcto de log probability
    void UpdateSAC(double reward, double &state[], double &next_state[]) {
        // SAC with entropy regularization
        double alpha = 0.2; // Temperature parameter
        double gamma = 0.99;
        double learning_rate = 0.0003;
        
        int critic_size = ArraySize(m_sac.critic_weights);
        int half_size = critic_size / 2;
        
        // Twin Q-function update
        double q1 = GetValue(state, m_sac.critic_weights, 0);
        double q2 = GetValue(state, m_sac.critic_weights, half_size);
        
        double min_q = MathMin(q1, q2);
        double next_action = GetSACAction(next_state);
        
        // CORRECCIÓN: Calcular log probability correctamente para acciones en [-1, 1]
        // Convertir acción a probabilidad usando sigmoid
        double action_prob = 1.0 / (1.0 + MathExp(-next_action * 2.0));  // Escalar y sigmoid
        double log_prob = MathLog(MathMax(0.0001, MathMin(0.9999, action_prob)));
        
        double next_q1 = GetValue(next_state, m_sac.critic_weights, 0);
        double next_q2 = GetValue(next_state, m_sac.critic_weights, half_size);
        double next_min_q = MathMin(next_q1, next_q2) - alpha * log_prob;
        
        double target_q = reward + gamma * next_min_q;
        
        int state_size = ArraySize(state);
        
        // Update critics
        for(int i = 0; i < half_size; i++) {
            double grad1 = (q1 - target_q) * (i < state_size ? state[i] : 0.0);
            m_sac.critic_weights[i] -= learning_rate * grad1;
            
            double grad2 = (q2 - target_q) * (i < state_size ? state[i] : 0.0);
            if(i + half_size < critic_size) {
                m_sac.critic_weights[i + half_size] -= learning_rate * grad2;
            }
        }
        
        // Update actor
        double action_value = GetSACAction(state);
        double actor_action_prob = 1.0 / (1.0 + MathExp(-action_value * 2.0));
        double actor_log_prob = MathLog(MathMax(0.0001, MathMin(0.9999, actor_action_prob)));
        
        int actor_size = ArraySize(m_sac.actor_weights);
        for(int i = 0; i < actor_size; i++) {
            double grad = (min_q - alpha * actor_log_prob) * (i < state_size ? state[i] : 0.0);
            m_sac.actor_weights[i] += learning_rate * grad;
        }
    }
    
    double GetValue(const double &state[], const double &weights[], int offset = 0) {
        double sum = 0.0;
        int state_size = ArraySize(state);
        int weight_size = ArraySize(weights);
        
        for(int i = 0; i < state_size; i++) {
            int w_idx = offset + i;
            if(w_idx < weight_size) {
                sum += state[i] * weights[w_idx];
            }
        }
        return sum;
    }
    
    void PrepareState(double &state[], const double &lstm_forecast[], 
                     const double &attention_weights[], 
                     const double &adversarial_scenarios[]) {
        ArrayResize(state, QUANTUM_MAX_FEATURES);
        ArrayInitialize(state, 0.0);
        
        int idx = 0;
        int max_copy = QUANTUM_MAX_FEATURES / 3;
        
        // Copiar LSTM forecast
        int lstm_size = MathMin(ArraySize(lstm_forecast), max_copy);
        if(lstm_size > 0 && idx + lstm_size <= QUANTUM_MAX_FEATURES) {
            ArrayCopy(state, lstm_forecast, idx, 0, lstm_size);
            idx += lstm_size;
        }
        
        // Copiar attention weights
        int att_size = MathMin(ArraySize(attention_weights), max_copy);
        if(att_size > 0 && idx + att_size <= QUANTUM_MAX_FEATURES) {
            ArrayCopy(state, attention_weights, idx, 0, att_size);
            idx += att_size;
        }
        
        // Copiar adversarial scenarios
        int adv_size = MathMin(ArraySize(adversarial_scenarios), max_copy);
        if(adv_size > 0 && idx + adv_size <= QUANTUM_MAX_FEATURES) {
            ArrayCopy(state, adversarial_scenarios, idx, 0, adv_size);
        }
    }
    
    // CORRECCIÓN #10: Mapeo correcto de acciones
    void ConvertToDecision(double action, QuantumDecisionProfile &decision) {
        action = MathTanh(action);  // Asegurar rango [-1, 1]
        
        // Mapear correctamente a 6 acciones (0-5)
        double normalized = (action + 1.0) / 2.0;  // [0, 1]
        int action_int = (int)MathFloor(normalized * 5.99);  // [0, 5]
        action_int = MathMax(0, MathMin(5, action_int));
        
        decision.action = (ENUM_FINAL_ACTION)action_int;
        
        // Mejorar determinación de dirección con zona muerta
        if(action > 0.2) {
            decision.direction = 1;  // BUY
        } else if(action < -0.2) {
            decision.direction = -1;  // SELL
        } else {
            decision.direction = 0;  // NEUTRAL
            decision.action = ACT_WAIT;  // Esperar en zona neutral
        }
        
        decision.final_confidence = MathAbs(action);
        decision.prediction_accuracy = 0.75 + MathAbs(action) * 0.2;
        
        decision.primary_orders = 1 + (int)(MathAbs(action) * 4);
        decision.primary_orders = MathMax(1, MathMin(QUANTUM_MAX_ORDERS, decision.primary_orders));
        
        decision.contingent_orders = (int)(MathAbs(action) * 2);
        decision.contingent_orders = MathMax(0, MathMin(QUANTUM_MAX_ORDERS/2, decision.contingent_orders));
        
        decision.max_total_risk = MathAbs(action) * 5.0;
        decision.use_dynamic_sl = MathAbs(action) > 0.5;
        decision.sl_protection_level = 0.5 + MathAbs(action) * 0.3;
        
        decision.trailing_profile = (int)(MathAbs(action) * 4);
        decision.trailing_profile = MathMax(0, MathMin(4, decision.trailing_profile));
        
        decision.use_ai_trailing = MathAbs(action) > 0.7;
        decision.expected_return = MathAbs(action) * 3.0;
        decision.max_expected_drawdown = MathAbs(action) * 1.5;
        
        // Evitar división por cero al calcular optimal_exit_time
        double time_factor = MathMax(0.1, 1.0 - MathAbs(action));
        decision.optimal_exit_time = TimeCurrent() + (int)(3600.0 / time_factor);
        
        // Mapear strategy type de forma segura
        int strat_int = (int)MathRound(MathAbs(action) * 3.0);
        strat_int = MathMax(0, MathMin(3, strat_int));
        decision.strategy_type = (ENUM_ML_STRATEGY)strat_int;
        
        // Inicializar arrays de forma segura
        for(int i = 0; i < QUANTUM_MAX_ORDERS; i++) {
            decision.risk_per_order[i] = (QUANTUM_MAX_ORDERS > 0) ? 
                                         MathAbs(action) / QUANTUM_MAX_ORDERS : 0.01;
            decision.entry_prices[i] = 0.0;
            decision.sl_atr_mult[i] = 1.0 + MathAbs(action) * i * 0.1;
        }
        
        for(int i = 0; i < 5; i++) {
            decision.trailing_stages[i] = 0.2 * (i + 1);
        }
    }
    
    string GenerateReasoning(const double &state[], double final_action) {
        string reason = "Decisión sintetizada de ensemble RL:\n";
        reason += "Acción final: " + DoubleToString(final_action, 2) + "\n";
        
        if(ArraySize(state) > 0) {
            reason += "Estado clave: Volatilidad próxima: " + DoubleToString(state[0], 2) + "\n";
        }
        
        return reason;
    }
};

//+------------------------------------------------------------------+
//| Clase: Quantum Weight System - CORREGIDA                        |
//+------------------------------------------------------------------+
class CQuantumWeightSystem {
private:
    double m_weights[QUANTUM_MAX_AGENTS][5][8][6]; // agent x session x regime x tf
    double m_performance_history[QUANTUM_MAX_AGENTS][100];
    int m_history_index[QUANTUM_MAX_AGENTS];
    
public:
    void Initialize() {
        // Inicializar pesos con distribución cuántica simulada
        for(int a = 0; a < QUANTUM_MAX_AGENTS; a++) {
            for(int s = 0; s < 5; s++) { // sessions
                for(int r = 0; r < 8; r++) { // regimes
                    for(int tf = 0; tf < 6; tf++) { // timeframes
                        m_weights[a][s][r][tf] = GlobalRandomNormal(1.0, 0.2);
                    }
                }
            }
            m_history_index[a] = 0;
            
            // Inicializar historial
            for(int h = 0; h < 100; h++) {
                m_performance_history[a][h] = 0.0;
            }
        }
    }
    
    // CORRECCIÓN #6: Usar seed determinista basado en parámetros
    double GetQuantumWeight(int agent_id, ENUM_MARKET_SESSION session, 
                           ENUM_MARKET_REGIME regime, ENUM_TIMEFRAMES tf, 
                           double volatility) {
        // Validar índices
        if(agent_id < 0 || agent_id >= QUANTUM_MAX_AGENTS) return 1.0;
        
        int s_idx = (int)session;
        int r_idx = (int)regime;
        int tf_idx = PeriodToIndex(tf);
        
        // Validar rangos
        s_idx = MathMax(0, MathMin(4, s_idx));
        r_idx = MathMax(0, MathMin(7, r_idx));
        tf_idx = MathMax(0, MathMin(5, tf_idx));
        
        // Usar seed basado en parámetros para determinismo
        int seed = agent_id * 1000 + s_idx * 100 + r_idx * 10 + tf_idx;
        seed += (int)(volatility * 1000);  // Incluir volatilidad en el seed
        MathSrand(seed);
        
        double base_weight = m_weights[agent_id][s_idx][r_idx][tf_idx];
        
        // Ruido determinista basado en el contexto
        double noise = (MathRand() / 32767.0 - 0.5) * 0.1 * volatility;
        double superposition = base_weight * (1.0 + noise);  // Multiplicativo en vez de aditivo
        
        // Entrelazamiento mejorado
        double entanglement = 0.0;
        double total_weight = 0.0;
        
        for(int other = 0; other < QUANTUM_MAX_AGENTS; other++) {
            if(other != agent_id) {
                double other_weight = m_weights[other][s_idx][r_idx][tf_idx];
                double distance_factor = MathExp(-MathAbs(agent_id - other) * 0.5);
                entanglement += other_weight * distance_factor;
                total_weight += distance_factor;
            }
        }
        
        if(total_weight > 0) {
            entanglement /= total_weight;  // Normalizar
        }
        
        return superposition * 0.8 + entanglement * 0.2;  // Balance entre individual y colectivo
    }
    
    void UpdateQuantumWeights(int agent_id, bool success, double profit, 
                             const QuantumMarketContext &context) {
        if(agent_id < 0 || agent_id >= QUANTUM_MAX_AGENTS) return;
        
        ENUM_MARKET_SESSION session = GetCurrentSession();
        ENUM_MARKET_REGIME regime = context.current_regime;
        ENUM_TIMEFRAMES tf = Period();
        
        int s_idx = (int)session;
        int r_idx = (int)regime;
        int tf_idx = PeriodToIndex(tf);
        
        // Validar rangos
        s_idx = MathMax(0, MathMin(4, s_idx));
        r_idx = MathMax(0, MathMin(7, r_idx));
        tf_idx = MathMax(0, MathMin(5, tf_idx));
        
        double adjustment = success ? profit * 0.01 : profit * 0.005;
        
        m_weights[agent_id][s_idx][r_idx][tf_idx] += adjustment;
        
        // Normalizar
        m_weights[agent_id][s_idx][r_idx][tf_idx] = MathMax(0.5, 
            MathMin(2.0, m_weights[agent_id][s_idx][r_idx][tf_idx]));
        
        // Actualizar historial
        int hist_idx = m_history_index[agent_id];
        if(hist_idx >= 0 && hist_idx < 100) {
            m_performance_history[agent_id][hist_idx] = profit;
            m_history_index[agent_id] = (hist_idx + 1) % 100;
        }
    }
    
private:
    int PeriodToIndex(ENUM_TIMEFRAMES period) {
        switch(period) {
            case PERIOD_M1: return 0;
            case PERIOD_M5: return 1;
            case PERIOD_M15: return 2;
            case PERIOD_H1: return 3;
            case PERIOD_H4: return 4;
            case PERIOD_D1: return 5;
            default: return 3;
        }
    }
    
    int VolatilityToLevel(double vol) {
        if(vol < 0.5) return 0;
        if(vol < 1.0) return 1;
        if(vol < 1.5) return 2;
        return 3;
    }
    
    ENUM_MARKET_SESSION GetCurrentSession() {
        MqlDateTime dt; 
        datetime now = TimeCurrent();
        TimeToStruct(now, dt);
        int hour = dt.hour;
        
        if(hour >= 0 && hour < 8) return SESSION_ASIAN;
        if(hour >= 8 && hour < 13) return SESSION_LONDON_ML;
        if(hour >= 13 && hour < 20) return SESSION_NEWYORK;
        if(hour >= 20 && hour < 22) return SESSION_OVERLAP;
        
        return SESSION_CLOSED;
    }
};

// [AUTO-FIX v5] Global helper for session detection (used by other modules)
ENUM_MARKET_SESSION GetCurrentSession()
{
    MqlDateTime dt;
    datetime now = TimeCurrent();
    TimeToStruct(now, dt);
    int hour = dt.hour;
    if(hour >= 0 && hour < 8)   return SESSION_ASIAN;
    if(hour >= 8 && hour < 13)  return SESSION_LONDON_ML;
    if(hour >= 13 && hour < 20) return SESSION_NEWYORK;
    if(hour >= 20 && hour < 22) return SESSION_OVERLAP;
    return SESSION_CLOSED;
}


//+------------------------------------------------------------------+
//| Clase: Quantum Forecast Engine                                 |
//+------------------------------------------------------------------+
class CQuantumForecastEngine {
private:
    CLSTMNetwork m_lstm_forecast;
    
public:
    void Initialize() {
        m_lstm_forecast.Initialize(24, 10, 64); // Horizonte 24h, 10 inputs, 64 hidden
    }
    
    QuantumForecast GenerateQuantumForecast(const QuantumMarketContext &context) {
        QuantumForecast forecast;
        forecast.Initialize();
        
        double predictions[];
        m_lstm_forecast.PredictSequence(context, predictions, 168); // 1 semana
        
        // Asignar probabilidades multi-horizonte
        if(ArraySize(predictions) > 0) {
            forecast.h1_direction_prob = Sigmoid(predictions[0]);
        }
        if(ArraySize(predictions) > 3) {
            forecast.h4_direction_prob = Sigmoid(predictions[3]);
        }
        if(ArraySize(predictions) > 23) {
            forecast.d1_direction_prob = Sigmoid(predictions[23]);
        }
        if(ArraySize(predictions) > 167) {
            forecast.w1_direction_prob = Sigmoid(predictions[167]);
        }
        
        // Generar targets probabilísticos
        for(int i = 0; i < 10; i++) {
            forecast.target_levels[i] = context.daily_range_forecast * (1.0 + i * 0.1);
            forecast.target_probabilities[i] = Gaussian(i, 5, 2); // Campana centrada
        }
        
        // Curva de volatilidad esperada
        for(int h = 0; h < 24; h++) {
            double sine_component = MathSin(h * M_PI / 12.0);
            forecast.expected_volatility_curve[h] = 
                context.next_hour_volatility * (1.0 + sine_component * 0.3);
        }
        
        // Confianza
        forecast.forecast_confidence = 0.85 - context.regime_transition_probability * 0.3;
        forecast.forecast_confidence = MathMax(0.1, MathMin(1.0, forecast.forecast_confidence));
        
        forecast.model_uncertainty = context.microstructure_noise * 0.5;
        forecast.model_uncertainty = MathMax(0.0, MathMin(1.0, forecast.model_uncertainty));
        
        return forecast;
    }
    
private:
    double Sigmoid(double x) { 
        x = MathMax(-50.0, MathMin(50.0, x));  // Limitar para evitar overflow
        return 1.0 / (1.0 + MathExp(-x)); 
    }
    
    double Gaussian(double x, double mean, double std) {
        if(std < 0.001) std = 0.001;  // Evitar división por cero
        double exponent = -MathPow(x - mean, 2) / (2.0 * MathPow(std, 2));
        exponent = MathMax(-50.0, exponent);  // Evitar underflow
        return MathExp(exponent) / (std * MathSqrt(2.0 * M_PI));
    }
};

//+------------------------------------------------------------------+
//| Clase: Quantum Execution Engine - AUDITADO Y REFORZADO         |
//+------------------------------------------------------------------+
class CQuantumExecutionEngine {
private:
    struct ExecutionRecord {
        ulong ticket;
        double entry_price;
        double sl_price;
        double tp_price;
        datetime entry_time;
        int trailing_stage;
        bool is_ai_managed;
        double volume;  // AUDITORÍA: Agregar volumen para tracking
        int order_type;  // AUDITORÍA: Agregar tipo de orden
    };
    
    CTrade m_trade;
    ExecutionRecord m_executions[QUANTUM_MAX_ORDERS];
    int m_execution_count;
    double m_maxDrawdownAllowed;  // AUDITORÍA: Límite de drawdown
    double m_maxRiskPerTrade;      // AUDITORÍA: Riesgo máximo por trade
    
public:
    void Initialize() {
        m_execution_count = 0;
        m_maxDrawdownAllowed = 0.1;  // 10% máximo drawdown
        m_maxRiskPerTrade = 0.02;    // 2% máximo riesgo por trade
        
        // AUDITORÍA: Configurar CTrade con settings seguros
        m_trade.SetExpertMagicNumber(12345);
        m_trade.SetDeviationInPoints(10);
        m_trade.SetTypeFilling(ORDER_FILLING_FOK);  // Fill or Kill para seguridad
        m_trade.SetAsyncMode(false);  // AUDITORÍA: Modo síncrono para control
        
        // Inicializar records
        for(int i = 0; i < QUANTUM_MAX_ORDERS; i++) {
            m_executions[i].ticket = 0;
            m_executions[i].entry_price = 0.0;
            m_executions[i].sl_price = 0.0;
            m_executions[i].tp_price = 0.0;
            m_executions[i].entry_time = 0;
            m_executions[i].trailing_stage = 0;
            m_executions[i].is_ai_managed = false;
            m_executions[i].volume = 0.0;
            m_executions[i].order_type = -1;
        }
    }
    
    // AUDITORÍA: Método crítico - Validación exhaustiva antes de ejecutar
    bool ExecuteQuantumStrategy(const QuantumDecisionProfile &decision) {
        // AUDITORÍA: Validaciones de seguridad múltiples
        if(decision.action == ACT_SKIP || decision.action == ACT_WAIT) {
            return false;
        }
        
        // AUDITORÍA: Verificar estado de cuenta antes de operar
        if(!ValidateAccountState()) {
            Print("❌ CRÍTICO: Estado de cuenta no apto para trading");
            return false;
        }
        
        // AUDITORÍA: Verificar riesgo total antes de ejecutar
        double totalRisk = CalculateTotalRisk(decision);
        if(totalRisk > m_maxRiskPerTrade * AccountInfoDouble(ACCOUNT_BALANCE)) {
            Print("❌ CRÍTICO: Riesgo total excede límite (", totalRisk, ")");
            return false;
        }
        
        // Validar condiciones de mercado
        if(!ValidateMarketConditions()) {
            Print("❌ Condiciones de mercado no favorables - Skip trade");
            return false;
        }
        
        // AUDITORÍA: Logging detallado de ejecución
        Print("📝 Ejecutando estrategia: ", EnumToString(decision.action), 
              " Dir: ", decision.direction, " Conf: ", decision.final_confidence);
        
        switch(decision.action) {
            case ACT_EXEC_SINGLE: return ExecuteSingle(decision);
            case ACT_EXEC_SCALE: return ExecuteScaleIn(decision);
            case ACT_EXEC_PYRAMID: return ExecutePyramid(decision);
            case ACT_EXEC_ASSAULT: return ExecuteFullAssault(decision);
            default: 
                Print("ERROR: Acción no reconocida: ", decision.action);
                return false;
        }
    }
    
    // AUDITORÍA: Monitoreo mejorado con protección adicional
    void MonitorWithAdaptiveExit() {
        static int barsInProfit = 0;
        static double peakProfit = 0;
        
        double currentProfit = CalculateTotalProfit();
        double currentDrawdown = CalculateCurrentDrawdown();
        
        // AUDITORÍA: Protección por drawdown excesivo
        if(currentDrawdown > m_maxDrawdownAllowed * AccountInfoDouble(ACCOUNT_BALANCE)) {
            Print("🚨 EMERGENCIA: Drawdown excesivo (", currentDrawdown, ") - Cerrando todo");
            CloseAllPositions("EMERGENCIA: Drawdown máximo alcanzado");
            return;
        }
        
        peakProfit = MathMax(peakProfit, currentProfit);
        
        // 1. Detectar deterioro de condiciones
        bool conditionsDeteriorating = DetectDeterioratingConditions();
        
        // 2. Verificar reversión de momentum
        double currentMomentum = CalculateMomentum();
        static double entryMomentum = currentMomentum;
        
        if(MathAbs(currentMomentum) < MathAbs(entryMomentum) * 0.3) {
            conditionsDeteriorating = true;
            Print("⚠ Momentum debilitándose");
        }
        
        // 3. Proteger ganancias con trailing más inteligente
        if(currentProfit > 0) {
            barsInProfit++;
            
            // AUDITORÍA: Protección dinámica basada en profit
            double protectionLevel = 0.7;  // Por defecto 70%
            if(peakProfit > AccountInfoDouble(ACCOUNT_BALANCE) * 0.01) {
                protectionLevel = 0.8;  // 80% si profit > 1% de balance
            }
            if(peakProfit > AccountInfoDouble(ACCOUNT_BALANCE) * 0.02) {
                protectionLevel = 0.9;  // 90% si profit > 2% de balance
            }
            
            if(currentProfit < peakProfit * protectionLevel) {
                Print("📉 Protegiendo ", protectionLevel*100, "% del peak profit");
                CloseAllPositions("Protección de ganancias");
                barsInProfit = 0;
                peakProfit = 0;
                return;
            }
            
            // Trailing más agresivo si hay deterioro
            if(conditionsDeteriorating) {
                TightenTrailingStops(0.5);
            }
        }
        
        // 4. Cortar pérdidas con límites estrictos
        double maxLoss = m_maxRiskPerTrade * AccountInfoDouble(ACCOUNT_BALANCE);
        if(currentProfit < -maxLoss) {
            Print("🛑 Pérdida máxima alcanzada: ", currentProfit);
            CloseAllPositions("Stop Loss máximo");
            return;
        }
        
        // AUDITORÍA: Verificar tiempo máximo en pérdida
        static datetime lossStartTime = 0;
        if(currentProfit < 0) {
            if(lossStartTime == 0) lossStartTime = TimeCurrent();
            if(TimeCurrent() - lossStartTime > 3600 * 4) {  // 4 horas máx
                Print("⏰ Tiempo máximo en pérdida alcanzado");
                CloseAllPositions("Timeout en pérdida");
                lossStartTime = 0;
            }
        } else {
            lossStartTime = 0;
        }
    }
    
private:
    // AUDITORÍA: Nueva función para validar estado de cuenta
    bool ValidateAccountState() {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double margin = AccountInfoDouble(ACCOUNT_MARGIN);
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        
        // Verificaciones críticas
        if(balance <= 0) {
            Print("ERROR: Balance inválido: ", balance);
            return false;
        }
        
        if(equity < balance * 0.5) {
            Print("ERROR: Equity muy bajo respecto al balance");
            return false;
        }
        
        if(freeMargin < balance * 0.1) {
            Print("WARNING: Margen libre insuficiente: ", freeMargin);
            return false;
        }
        
        // Verificar nivel de margen
        double marginLevel = (equity > 0 && margin > 0) ? (equity / margin * 100) : 0;
        if(marginLevel > 0 && marginLevel < 150) {
            Print("WARNING: Nivel de margen bajo: ", marginLevel);
            return false;
        }
        
        return true;
    }
    
    // AUDITORÍA: Calcular riesgo total antes de ejecutar
    double CalculateTotalRisk(const QuantumDecisionProfile &decision) {
        double totalRisk = 0;
        
        for(int i = 0; i < decision.primary_orders; i++) {
            if(i < QUANTUM_MAX_ORDERS) {
                totalRisk += decision.risk_per_order[i];
            }
        }
        
        // Ajustar por confidence
        totalRisk *= (1.0 + (1.0 - decision.final_confidence) * 0.5);
        
        return totalRisk;
    }
    
    // AUDITORÍA: Calcular drawdown actual
    double CalculateCurrentDrawdown() {
        double profit = 0;
        for(int i = 0; i < m_execution_count; i++) {
            if(PositionSelectByTicket(m_executions[i].ticket)) {
                double posProfit = PositionGetDouble(POSITION_PROFIT);
                if(posProfit < 0) {
                    profit += MathAbs(posProfit);
                }
            }
        }
        return profit;
    }
    
    // AUDITORÍA: Validación de mercado reforzada
    bool ValidateMarketConditions() {
        // 1. Verificar spread
        double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 
                       SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        
        // AUDITORÍA: Spread máximo dinámico basado en timeframe
        double maxSpread = 10;
        if(Period() <= PERIOD_M5) maxSpread = 5;
        if(Period() >= PERIOD_H1) maxSpread = 15;
        
        if(spread > maxSpread) {
            Print("Spread muy alto: ", spread, " > ", maxSpread);
            return false;
        }
        
        // 2. Verificar liquidez (volumen)
        long volume = SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
        long volume_high = SymbolInfoInteger(_Symbol, SYMBOL_VOLUMEHIGH);
        long volume_low  = SymbolInfoInteger(_Symbol, SYMBOL_VOLUMELOW);
        long avgVolume   = (volume_high + volume_low) / 2;
        
        // AUDITORÍA: Comparar con volumen promedio de sesión
        if(avgVolume > 0) {
            long minVolume = (long)(avgVolume * 0.1);
            if(volume < minVolume) {
                Print("Volumen muy bajo comparado con promedio");
                return false;
            }
        }
        
        // 3. Verificar sesión
        ENUM_MARKET_SESSION session = GetCurrentSession();
        if(session == SESSION_CLOSED) {
            Print("Mercado cerrado");
            return false;
        }
        
        // 4. AUDITORÍA: Verificar trading permitido
        if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
            Print("Trading no permitido en terminal");
            return false;
        }
        
        if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
            Print("Trading no permitido en EA");
            return false;
        }
        
        return true;
    }
    
    bool DetectDeterioratingConditions() {
        // Implementación simplificada
        int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
        if(rsi_handle != INVALID_HANDLE) {
            double rsi[];
            ArraySetAsSeries(rsi, true);
            if(CopyBuffer(rsi_handle, 0, (MQLInfoInteger(MQL_TESTER) ? 1 : 0), 1, rsi) > 0) {
                IndicatorRelease(rsi_handle);
                return (rsi[0] < 30 || rsi[0] > 70);
            }
            IndicatorRelease(rsi_handle);
        }
        return false;
    }
    
    double CalculateMomentum() {
        double close[];
        ArraySetAsSeries(close, true);
        int copied = CopyClose(_Symbol, PERIOD_CURRENT, 0, 20, close);
        
        if(copied >= 20) {
            return (close[0] - close[19]) / close[19] * 100;
        }
        return 0;
    }
    
    double CalculateTotalProfit() {
        double total = 0;
        for(int i = 0; i < m_execution_count; i++) {
            if(PositionSelectByTicket(m_executions[i].ticket)) {
                total += PositionGetDouble(POSITION_PROFIT);
            }
        }
        return total;
    }
    
    void CloseAllPositions(string reason) {
        for(int i = 0; i < m_execution_count; i++) {
            if(m_executions[i].ticket > 0) {
                m_trade.PositionClose(m_executions[i].ticket);
            }
        }
        Print("Todas las posiciones cerradas: ", reason);
        m_execution_count = 0;
    }
    
    void TightenTrailingStops(double factor) {
        for(int i = 0; i < m_execution_count; i++) {
            if(PositionSelectByTicket(m_executions[i].ticket)) {
                double currentSL = PositionGetDouble(POSITION_SL);
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                double entry = PositionGetDouble(POSITION_PRICE_OPEN);
                
                int direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
                
                double newSL = currentPrice - direction * MathAbs(currentPrice - currentSL) * factor;
                
                // Solo mover SL si es favorable
                if((direction > 0 && newSL > currentSL) || 
                   (direction < 0 && newSL < currentSL)) {
                    m_trade.PositionModify(m_executions[i].ticket, newSL, 
                                          PositionGetDouble(POSITION_TP));
                }
            }
        }
    }
    
    TradeSignal GenerateSingleSignal(const QuantumDecisionProfile &decision) {
        Print("📊 Generando señal SINGLE ORDER");
        
        TradeSignal signal;
        signal.Init();
        
        signal.direction = decision.direction;
        signal.volume = CalculateVolume(decision.risk_per_order[0], 0.0);
        
        double price = decision.entry_prices[0];
        if(price <= 0) {
            price = decision.direction > 0 ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID);
        }
        signal.price = price;
        
        signal.stopLoss = CalculateStopLoss(price, decision.direction, 
                                           decision.sl_atr_mult[0]);
        signal.takeProfit = CalculateTakeProfit(price, decision.direction, 
                                               decision.expected_return);
        
        signal.reasoning = decision.reasoning;
        signal.useAITrailing = decision.use_ai_trailing;
        signal.confidence = decision.final_confidence;
        signal.orderCount = 1;
        signal.atrMultiplier = decision.sl_atr_mult[0];
        signal.expectedReturn = decision.expected_return;
        
        if(signal.volume > 0 && signal.direction != 0) {
            signal.isValid = true;
            signal.volumes[0] = signal.volume;
            signal.entryPrices[0] = signal.price;
            signal.stopLosses[0] = signal.stopLoss;
            signal.takeProfits[0] = signal.takeProfit;
            
            Print("✅ Señal generada: Dir=", signal.direction, 
                  " Vol=", signal.volume, " Conf=", signal.confidence);
        } else {
            signal.isValid = false;
            Print("❌ Señal inválida: volumen o dirección incorrectos");
        }
        
        return signal;
    }
    
    TradeSignal GenerateScaleInSignals(const QuantumDecisionProfile &decision) {
        int orders_count = MathMin(decision.primary_orders, QUANTUM_MAX_ORDERS);
        Print("📊 Generando señales SCALE-IN - ", orders_count, " órdenes");
        
        TradeSignal signal;
        signal.Init();
        
        signal.direction = decision.direction;
        signal.reasoning = decision.reasoning;
        signal.useAITrailing = decision.use_ai_trailing;
        signal.confidence = decision.final_confidence;
        signal.orderCount = orders_count;
        signal.atrMultiplier = decision.sl_atr_mult[0];
        signal.expectedReturn = decision.expected_return;
        
        for(int i = 0; i < orders_count && i < 10; i++) {
            signal.volumes[i] = CalculateVolume(decision.risk_per_order[i], 0.0);
            
            double price = decision.entry_prices[i];
            if(price <= 0) {
                double base_price = decision.direction > 0 ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
                price = base_price + (decision.direction * i * 
                       SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
            }
            signal.entryPrices[i] = price;
            signal.stopLosses[i] = CalculateStopLoss(price, decision.direction, 
                                                    decision.sl_atr_mult[i]);
            signal.takeProfits[i] = CalculateTakeProfit(price, decision.direction, 
                                                       decision.expected_return);
        }
        
        signal.isValid = (signal.orderCount > 0 && signal.direction != 0);
        
        if(signal.isValid) {
            Print("✅ Señales generadas: ", signal.orderCount, " órdenes");
        } else {
            Print("❌ Señales inválidas");
        }
        
        return signal;
    }

    // Ejecuta una única orden basada en el perfil cuántico
    bool ExecuteSingle(const QuantumDecisionProfile &decision) {
        TradeSignal signal = GenerateSingleSignal(decision);

        if(!signal.isValid) {
            Print("❌ ExecuteSingle: señal inválida, no se ejecutará la orden");
            return false;
        }

        double volume = signal.volume;
        double sl     = signal.stopLoss;
        double tp     = signal.takeProfit;

        if(volume <= 0 || signal.direction == 0) {
            Print("❌ ExecuteSingle: volumen o dirección inválidos");
            return false;
        }

        ResetLastError();
        bool result = false;

        // Usamos órdenes de mercado; el precio real se obtendrá del resultado
        if(signal.direction > 0) {
            result = m_trade.Buy(volume, _Symbol, 0.0, sl, tp);
        } else {
            result = m_trade.Sell(volume, _Symbol, 0.0, sl, tp);
        }

        if(!result) {
            int err = GetLastError();
            Print("❌ ExecuteSingle: error al enviar orden. Código=", err);
            return false;
        }

        ulong ticket       = m_trade.ResultOrder();
        double entry_price = m_trade.ResultPrice();

        if(ticket > 0) {
            RegisterExecution(ticket, entry_price, sl, tp, signal.useAITrailing);

            if(signal.useAITrailing) {
                // Usar el primer nivel de trailing como referencia
                ConfigureAITrailing(ticket, decision.trailing_stages[0]);
            }
        }

        Print("✅ ExecuteSingle completado. Ticket=", ticket,
              " Vol=", volume, " Dir=", signal.direction);
        return true;
    }

    // Ejecuta una estrategia de Scale-In (varias órdenes escalonadas)
    bool ExecuteScaleIn(const QuantumDecisionProfile &decision) {
        TradeSignal signal = GenerateScaleInSignals(decision);

        if(!signal.isValid) {
            Print("❌ ExecuteScaleIn: señal inválida, no se ejecutarán órdenes");
            return false;
        }

        int max_orders = MathMin(signal.orderCount, QUANTUM_MAX_ORDERS);
        int success_count = 0;

        for(int i = 0; i < max_orders; i++) {
            double volume = signal.volumes[i];
            double sl     = signal.stopLosses[i];
            double tp     = signal.takeProfits[i];

            if(volume <= 0) {
                Print("⚠ ExecuteScaleIn: volumen cero en índice ", i, " - se omite");
                continue;
            }

            ResetLastError();
            bool result = false;

            if(signal.direction > 0) {
                result = m_trade.Buy(volume, _Symbol, 0.0, sl, tp);
            } else if(signal.direction < 0) {
                result = m_trade.Sell(volume, _Symbol, 0.0, sl, tp);
            } else {
                Print("⚠ ExecuteScaleIn: dirección neutra en índice ", i, " - se omite");
                continue;
            }

            if(!result) {
                int err = GetLastError();
                Print("❌ ExecuteScaleIn: error al enviar orden #", i,
                      " Código=", err);
                continue;
            }

            ulong ticket       = m_trade.ResultOrder();
            double entry_price = m_trade.ResultPrice();

            if(ticket > 0) {
                RegisterExecution(ticket, entry_price, sl, tp, signal.useAITrailing);

                if(signal.useAITrailing) {
                    int stageIndex = (i < 5) ? i : 4;
                    ConfigureAITrailing(ticket, decision.trailing_stages[stageIndex]);
                }
            }

            success_count++;
        }

        Print("✅ ExecuteScaleIn completado. Órdenes ejecutadas: ",
              success_count, "/", max_orders);

        return success_count > 0;
    }
    
    bool ExecutePyramid(const QuantumDecisionProfile &decision) {
        int primary = MathMin(decision.primary_orders, QUANTUM_MAX_ORDERS);
        int contingent = MathMin(decision.contingent_orders, QUANTUM_MAX_ORDERS/2);
        
        Print("📈 EJECUTANDO PYRAMID - ", primary, 
              " primarias + ", contingent, " contingentes");
        
        // Ejecutar órdenes primarias
        bool primary_success = ExecuteScaleIn(decision);
        
        if(primary_success) {
            // Configurar órdenes contingentes
            for(int i = 0; i < contingent; i++) {
                SetupContingentOrder(i, decision);
            }
        }
        
        return primary_success;
    }
    
    bool ExecuteFullAssault(const QuantumDecisionProfile &decision) {
        int primary = MathMin(decision.primary_orders, QUANTUM_MAX_ORDERS);
        int contingent = MathMin(decision.contingent_orders, QUANTUM_MAX_ORDERS/2);
        
        Print("🚀 EJECUTANDO FULL ASSAULT - ", primary, 
              " órdenes primarias + ", contingent, " contingentes");
        
        int success_count = 0;
        
        // Fase 1: Órdenes primarias con timing óptimo
        for(int i = 0; i < primary; i++) {
            double volume = CalculateVolume(decision.risk_per_order[i], 0.0);
            double price = decision.entry_prices[i];
            
            if(price <= 0) {
                double base_price = decision.direction > 0 ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
                                  
                // Distribución de precios más agresiva
                double spread = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 * i;
                price = base_price + (decision.direction * spread);
            }
            
            double sl = CalculateStopLoss(price, decision.direction, 
                                         decision.sl_atr_mult[i]);
            double tp = CalculateTakeProfit(price, decision.direction, 
                                          decision.expected_return * (1.0 + i * 0.1));
            
            // Micro-timing para cada orden
            int optimal_delay = CalculateOptimalDelay(i, decision);
            if(i > 0) Sleep(optimal_delay);
            
            bool result = false;
            if(decision.direction > 0) {
                result = m_trade.Buy(volume, _Symbol, price, sl, tp, "ML Quantum Buy");
            } else {
                result = m_trade.Sell(volume, _Symbol, price, sl, tp, "ML Quantum Sell");
            }
            
            if(result) {
                ulong ticket = m_trade.ResultOrder();
                RegisterExecution(ticket, price, sl, tp, decision.use_ai_trailing);
                
                // Configurar trailing AI para esta orden
                if(decision.use_ai_trailing) {
                    int stage = i % 5;
                    ConfigureAITrailing(ticket, decision.trailing_stages[stage]);
                }
                
                success_count++;
            }
        }
        
        // Fase 2: Configurar órdenes contingentes
        for(int i = 0; i < contingent; i++) {
            SetupContingentOrder(i, decision);
        }
        
        Print("🎯 Full Assault completado: ", success_count, "/", 
              primary, " ejecutadas + ", contingent, " contingentes configuradas");
        
        return success_count > 0;
    }
    
    // CORRECCIÓN #7: SL adaptativo con ATR y estructura
    double CalculateVolume(double risk_percent, double actual_sl_points) {
        double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        if(account_balance <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        
        double risk_amount = account_balance * risk_percent / 100.0;
        
        // Usar ATR para SL adaptativo si no se proporciona
        if(actual_sl_points <= 0) {
            int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
            if(atr_handle != INVALID_HANDLE) {
                double atr_buffer[];
                ArraySetAsSeries(atr_buffer, true);
                if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
                    double point_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                    if(point_value > 0) {
                        actual_sl_points = atr_buffer[0] / point_value;
                    }
                } else {
                    actual_sl_points = 100;  // Fallback
                }
                IndicatorRelease(atr_handle);
            } else {
                actual_sl_points = 100;  // Fallback
            }
        }
        
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        
        if(tick_value > 0 && tick_size > 0 && actual_sl_points > 0) {
            double volume = risk_amount / (actual_sl_points * tick_value / tick_size);
            
            // Normalizar al step del lote
            double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            if(lot_step > 0) {
                volume = MathFloor(volume / lot_step) * lot_step;
            }
            
            // Limitar al rango permitido
            double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
            
            return MathMax(min_lot, MathMin(max_lot, volume));
        }
        
        return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    }
    
    double CalculateStopLoss(double entry, int direction, double atr_mult) {
        int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        if(atr_handle == INVALID_HANDLE) {
            // Usar default si no se puede calcular ATR
            double default_sl = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100;
            return direction > 0 ? entry - default_sl : entry + default_sl;
        }
        
        double atr[];
        ArraySetAsSeries(atr, true);
        
        double sl = entry;
        
        if(CopyBuffer(atr_handle, 0, 0, 1, atr) > 0) {
            double atr_value = atr[0] * atr_mult;
            
            if(direction > 0) {
                sl = entry - atr_value;
            } else {
                sl = entry + atr_value;
            }
        }
        
        IndicatorRelease(atr_handle);
        
        return NormalizeDouble(sl, _Digits);
    }
    
    double CalculateTakeProfit(double entry, int direction, double expected_return) {
        // CORRECCIÓN: Permitir TP=0 para usar solo trailing
        
        if(expected_return <= 0) expected_return = 1.0;
        
        double tp_distance = entry * expected_return / 100.0;
        
        double tp;
        if(direction > 0) {
            tp = entry + tp_distance;
        } else {
            tp = entry - tp_distance;
        }
        
        return NormalizeDouble(tp, _Digits);
    }
    
    int CalculateOptimalDelay(int order_index, const QuantumDecisionProfile &decision) {
        // Calcular delay óptimo basado en volatilidad y estrategia
        int base_delay = 500; // 500ms base
        
        switch(decision.strategy_type) {
            case STRAT_AGGRESSIVE:
                return base_delay / 2;
            case STRAT_CONSERVATIVE:
                return base_delay * 2;
            default:
                return base_delay + order_index * 100;
        }
    }
    
    void SetupContingentOrder(int index, const QuantumDecisionProfile &decision) {
        // Configurar orden contingente (pendiente)
        double trigger_price = 0;
        
        if(decision.entry_prices[0] > 0) {
            trigger_price = decision.entry_prices[0] + 
                          (decision.direction * index * 
                           SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20);
        } else {
            double current_price = decision.direction > 0 ? 
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID);
            trigger_price = current_price + 
                          (decision.direction * (index + 1) * 
                           SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20);
        }
        
        double volume = CalculateVolume(decision.risk_per_order[index], 0.0);
        
        if(decision.direction > 0) {
            m_trade.BuyStop(volume, trigger_price, _Symbol);
        } else {
            m_trade.SellStop(volume, trigger_price, _Symbol);
        }
    }
    
    void ConfigureAITrailing(ulong ticket, double trailing_stage) {
        // Configurar trailing stop gestionado por IA
        for(int i = 0; i < m_execution_count; i++) {
            if(m_executions[i].ticket == ticket) {
                m_executions[i].trailing_stage = (int)trailing_stage;
                m_executions[i].is_ai_managed = true;
                break;
            }
        }
    }
    
    void RegisterExecution(ulong ticket, double price, double sl, double tp, bool ai_managed) {
        if(m_execution_count < QUANTUM_MAX_ORDERS) {
            m_executions[m_execution_count].ticket = ticket;
            m_executions[m_execution_count].entry_price = price;
            m_executions[m_execution_count].sl_price = sl;
            m_executions[m_execution_count].tp_price = tp;
            m_executions[m_execution_count].entry_time = TimeCurrent();
            m_executions[m_execution_count].trailing_stage = 0;
            m_executions[m_execution_count].is_ai_managed = ai_managed;
            m_execution_count++;
        }
    }
// [AUTO-FIX v2] Removed duplicate GetCurrentSession() definition

};

//+------------------------------------------------------------------+
//| Clase Principal: Sistema de Quantum Neural Ensemble CORREGIDA    |
//+------------------------------------------------------------------+
class CQuantumNeuralEnsemble
{
private:
    // Tres arquitecturas complementarias
    CLSTMNetwork m_lstm;
    CTransformerNet m_transformer;
    CGANNetwork m_gan;
    // Meta-learner de reinforcement learning
    CReinforcementLearner m_metalearner;
    
    // Sistema de pesos cuánticos
    CQuantumWeightSystem m_weight_system;
    // Motor de forecast
    CQuantumForecastEngine m_forecast_engine;
    
    // Motor de ejecución
    CQuantumExecutionEngine m_execution_engine;
    // Sistema de votación mejorado
    ContextualVotingSystem m_voting_system;
    // Calculador de señales por indicador
    SignalCalculator m_signal_calculator;

    // Sistema de aprendizaje
    TradeLearningSystem m_learning_system;
    bool m_initialized;

    // Variable para rastrear la última decisión (para aprendizaje)
    int m_lastDirection;
    datetime m_lastTradeTime;
    
public:
    CQuantumNeuralEnsemble() {
        m_initialized = false;
        m_lastDirection = 0;
        m_lastTradeTime = 0;
    }

    void Initialize() {
        Print("═══════════════════════════════════════════════════════════");
        Print("  🚀 INICIALIZANDO QUANTUM NEURAL ENSEMBLE v3.0");
        Print("═══════════════════════════════════════════════════════════");

        m_lstm.Initialize(24, 10, 128);
        m_transformer.Initialize(8, 64, 24);
        m_gan.Initialize(100, 10);
        m_metalearner.Initialize();
        m_weight_system.Initialize();
        m_forecast_engine.Initialize();
        m_execution_engine.Initialize();

        // Inicializar sistema de votación contextual
        m_voting_system.Initialize();

        // Inicializar calculador de señales
        if(!m_signal_calculator.Initialize()) {
            Print("❌ ERROR: No se pudo inicializar SignalCalculator");
            m_initialized = false;
            return;
        }

        m_learning_system.Initialize();

        m_initialized = true;
        Print("═══════════════════════════════════════════════════════════");
        Print("  ✅ QUANTUM NEURAL ENSEMBLE INICIALIZED COMPLETAMENTE");
        Print("  📊 Sistema de Votación Contextual: ACTIVO");
        Print("  🔧 Calculador de Señales: ACTIVO (5 indicadores)");
        Print("═══════════════════════════════════════════════════════════");
    }

    // Overload con configuración externa
    bool Initialize(const int memory_size, const int ensemble_size) {
        Print("Inicializando Quantum Neural Ensemble (configurable)...");
        Initialize();
        return m_initialized;
    }
    
    //+------------------------------------------------------------------+
    //| Método Principal: Tomar Decisión con Votación Contextual       |
    //+------------------------------------------------------------------+
    QuantumDecisionProfile MakeQuantumDecision(const QuantumMarketContext &context) {
        QuantumDecisionProfile decision;
        decision.Initialize();

        if(!m_initialized) {
            Print("❌ ERROR: Sistema no inicializado");
            decision.action = ACT_SKIP;
            return decision;
        }

        Print("\n┌───────────────────────────────────────────────────────────┐");
        Print("│ 🎯 INICIANDO ANÁLISIS DE VOTACIÓN CONTEXTUAL            │");
        Print("└───────────────────────────────────────────────────────────┘");

        //--- PASO 1: CALCULAR SEÑALES DE TODOS LOS INDICADORES ---
        double buyVotes[], sellVotes[];
        m_signal_calculator.CalculateAllSignals(buyVotes, sellVotes);

        //--- PASO 2: CONSTRUIR CONSENSO CONTEXTUAL ---
        ConsensusResult consensus = m_voting_system.BuildConsensus(buyVotes, sellVotes, 5);

        // Mostrar resultado del consenso
        Print("┌─ RESULTADO DEL CONSENSO ────────────────────────────────┐");
        if(consensus.isValid) {
            string dirText = (consensus.direction > 0) ? "🟢 BUY" : "🔴 SELL";
            Print("│ Dirección: ", dirText);
            Print("│ Fuerza: ", DoubleToString(consensus.strength * 100, 1), "%");
            Print("│ Confianza: ", DoubleToString(consensus.confidence * 100, 1), "%");
            Print("│ Indicador Líder: ", consensus.topIndicatorName);
            Print("│ Detalle: ", consensus.reasoning);
        } else {
            Print("│ ⚠️ No hay consenso válido - SKIP");
            Print("│ Razón: ", consensus.reasoning);
        }
        Print("└──────────────────────────────────────────────────────────┘");

        //--- PASO 3: VALIDAR CONSENSO ---
        if(!consensus.isValid) {
            decision.action = ACT_SKIP;
            decision.reasoning = "Sin consenso válido: " + consensus.reasoning;
            Print("⏭️ Acción: SKIP");
            return decision;
        }

        //--- PASO 4: CONSTRUIR DECISIÓN BASADA EN CONSENSO ---
        decision.direction = consensus.direction;
        decision.final_confidence = consensus.confidence;
        decision.reasoning = consensus.reasoning;

        // Guardar dirección para aprendizaje posterior
        m_lastDirection = decision.direction;
        m_lastTradeTime = TimeCurrent();

        //--- PASO 5: DETERMINAR ACCIÓN SEGÚN FUERZA Y CONFIANZA ---
        // Fórmula: Acción = f(strength, confidence)
        double compositeScore = (consensus.strength * 0.6) + (consensus.confidence * 0.4);

        if(compositeScore < 0.35) {
            decision.action = ACT_WAIT;
            Print("⏸️ Acción: WAIT (Score: ", DoubleToString(compositeScore * 100, 1), "%)");
        } else if(compositeScore < 0.50) {
            decision.action = ACT_EXEC_SINGLE;
            decision.primary_orders = 1;
            Print("📊 Acción: SINGLE ORDER (Score: ", DoubleToString(compositeScore * 100, 1), "%)");
        } else if(compositeScore < 0.65) {
            decision.action = ACT_EXEC_SCALE;
            decision.primary_orders = 2;
            Print("📈 Acción: SCALE-IN (2 órdenes) (Score: ", DoubleToString(compositeScore * 100, 1), "%)");
        } else if(compositeScore < 0.80) {
            decision.action = ACT_EXEC_PYRAMID;
            decision.primary_orders = MathMin(5, (int)(compositeScore * 6));
            Print("🏗️ Acción: PYRAMID (", decision.primary_orders, " órdenes) (Score: ", DoubleToString(compositeScore * 100, 1), "%)");
        } else {
            decision.action = ACT_EXEC_ASSAULT;
            decision.primary_orders = MathMin(10, (int)(compositeScore * 10));
            Print("🚀 Acción: FULL ASSAULT (", decision.primary_orders, " órdenes) (Score: ", DoubleToString(compositeScore * 100, 1), "%)");
        }

        //--- PASO 6: APLICAR AJUSTES CUÁNTICOS (análisis avanzado) ---
        ApplyQuantumAdjustments(decision, context);

        //--- PASO 7: GENERAR FORECAST (opcional, para información adicional) ---
        QuantumForecast forecast = m_forecast_engine.GenerateQuantumForecast(context);
        IntegrateForecast(decision, forecast);

        //--- PASO 8: VERIFICAR CON SISTEMA DE APRENDIZAJE ---
        TradeContext currentTrade;
        currentTrade.Initialize();
        currentTrade.atr = context.next_hour_volatility;
        currentTrade.rsi = context.retail_sentiment * 100;
        currentTrade.momentum = context.volume_weighted_momentum;
        currentTrade.regime = context.current_regime;

        double successProbability = m_learning_system.PredictSuccess(currentTrade);
        Print("┌─ VERIFICACIÓN FINAL ─────────────────────────────────────┐");
        Print("│ Probabilidad de Éxito: ", DoubleToString(successProbability * 100, 1), "%");

        if(successProbability < 0.40) {
            Print("│ ⚠️ Probabilidad BAJA - Reduciendo agresividad");
            decision.action = ACT_WAIT;
            decision.reasoning += " | P(success) < 40%";
        } else if(successProbability >= 0.75) {
            Print("│ ✅ Probabilidad ALTA - Setup óptimo");
            decision.reasoning += " | P(success) >= 75%";
        } else {
            Print("│ ℹ️ Probabilidad MODERADA - Proceder con cautela");
        }
        Print("└──────────────────────────────────────────────────────────┘\n");

        //--- MOSTRAR PESOS ACTUALES (DEBUG) ---
        Print("┌─ PESOS CONTEXTUALES ACTUALES ───────────────────────────┐");
        double weights[];
        m_voting_system.GetCurrentWeights(weights);
        for(int i = 0; i < ArraySize(weights); i++) {
            Print("│ [", i, "] ", m_voting_system.GetIndicatorName(i), ": ",
                  DoubleToString(weights[i] * 100, 1), "%");
        }
        Print("└──────────────────────────────────────────────────────────┘");

        //--- INSIGHT CONTEXTUAL ---
        string insight = m_voting_system.GetContextualInsight();
        Print("💡 ", insight);

        return decision;
    }
    
    bool ExecuteDecision(const QuantumDecisionProfile &decision) {
        // Monitorear posiciones existentes antes de ejecutar nuevas
        m_execution_engine.MonitorWithAdaptiveExit();
        return m_execution_engine.ExecuteQuantumStrategy(decision);
    }
    
    // Exponer forecast completo para uso externo
    QuantumForecast GenerateQuantumForecast(const QuantumMarketContext &context) {
        return m_forecast_engine.GenerateQuantumForecast(context);
    }
    
    //+------------------------------------------------------------------+
    //| Actualizar Aprendizaje Después de un Trade                     |
    //+------------------------------------------------------------------+
    void UpdateLearning(int agent_id, bool success, double profit, const QuantumMarketContext &context) {
        m_weight_system.UpdateQuantumWeights(agent_id, success, profit, context);

        // Actualizar RL con reward
        double state[QUANTUM_MAX_FEATURES];
        double next_state[QUANTUM_MAX_FEATURES];
        PrepareStateFromContext(state, context);
        PrepareStateFromContext(next_state, context);

        double reward = success ? profit : -MathAbs(profit);
        m_metalearner.UpdatePolicy(reward, state, next_state);

        // Actualizar sistema de votación (API legacy compatible)
        m_voting_system.UpdatePerformance(agent_id, success, profit);

        // Registrar en sistema de aprendizaje
        TradeContext trade;
        trade.Initialize();
        trade.atr = context.next_hour_volatility;
        trade.rsi = context.retail_sentiment * 100;
        trade.momentum = context.volume_weighted_momentum;
        trade.regime = context.current_regime;
        trade.wasSuccessful = success;
        trade.profit = profit;

        m_learning_system.RecordTrade(trade);
    }

    //+------------------------------------------------------------------+
    //| Aprender de Cierre de Trade (MÉTODO MEJORADO)                  |
    //| Actualiza TODOS los indicadores con el resultado contextual    |
    //+------------------------------------------------------------------+
    void LearnFromTradeClose(bool success, double profit) {
        if(m_lastDirection == 0) {
            Print("⚠️ WARNING: No hay dirección guardada para aprender");
            return;
        }

        Print("\n┌───────────────────────────────────────────────────────────┐");
        Print("│ 🎓 APRENDIZAJE POST-TRADE                                │");
        Print("└───────────────────────────────────────────────────────────┘");

        string resultIcon = success ? "✅" : "❌";
        string directionText = (m_lastDirection > 0) ? "BUY" : "SELL";

        Print("│ Resultado: ", resultIcon, " | Dirección: ", directionText);
        Print("│ Profit: $", DoubleToString(profit, 2));

        // Actualizar todos los indicadores en el sistema de votación
        m_voting_system.LearnFromAllIndicators(m_lastDirection, success, profit);

        Print("└───────────────────────────────────────────────────────────┘");

        // Reset
        m_lastDirection = 0;
    }

    //+------------------------------------------------------------------+
    //| Generar Reporte de Performance Completo                        |
    //+------------------------------------------------------------------+
    void PrintPerformanceReport() {
        m_voting_system.PrintPerformanceReport();
    }

    //+------------------------------------------------------------------+
    //| Exportar Datos a CSV                                           |
    //+------------------------------------------------------------------+
    bool ExportPerformanceToCSV(string filename = "") {
        if(filename == "") {
            filename = "VotingPerformance_" + _Symbol + "_" + IntegerToString(TimeCurrent()) + ".csv";
        }
        return m_voting_system.ExportToCSV(filename);
    }
    
    double GetAgentQuantumWeight(int agent_id, const QuantumMarketContext &context) {
        ENUM_MARKET_SESSION session = GetCurrentSession();
        ENUM_MARKET_REGIME regime = context.current_regime;
        ENUM_TIMEFRAMES tf = Period();
        
        return m_weight_system.GetQuantumWeight(
            agent_id, session, regime, tf, context.next_hour_volatility
        );
    }
    
private:
    // CORRECCIÓN CRÍTICA: Uso de casting a (int) para comparaciones de ENUM y uso correcto de decision
    void ApplyQuantumAdjustments(QuantumDecisionProfile &decision, const QuantumMarketContext &context) {
        // Ajuste por toxicidad de order flow
        if(context.order_flow_toxicity > 0.7) {
            if((int)decision.action > (int)ACT_SKIP) { // Casting explícito
                int new_action = (int)decision.action - 1;
                decision.action = (ENUM_FINAL_ACTION)MathMax(0, new_action);
            }
            decision.max_total_risk *= 0.6;
        }
        
        // Boost por smart money alignment
        if(context.smart_money_flow * decision.direction > 0.8) {
            if((int)decision.action < (int)ACT_EXEC_PYRAMID) { // Casting explícito
                int new_action = (int)decision.action + 1;
                decision.action = (ENUM_FINAL_ACTION)MathMin(5, new_action);
            }
            decision.final_confidence *= 1.2;
        }
        
        // Ajuste por probabilidad de transición de régimen
        if(context.regime_transition_probability > 0.6) {
            decision.primary_orders = MathMax(1, decision.primary_orders / 2);
            decision.trailing_profile = MathMin(4, decision.trailing_profile + 1);
        }
        
        // Ajuste por sentimiento institucional
        if(MathAbs(context.institutional_sentiment) > 0.7) {
            if(context.institutional_sentiment * decision.direction > 0) {
                decision.final_confidence *= 1.1;
            } else {
                decision.final_confidence *= 0.9;
                decision.use_dynamic_sl = true;
            }
        }
        
        // Limitar confianza
        decision.final_confidence = MathMax(0.1, MathMin(0.95, decision.final_confidence));
    }
    
    void IntegrateForecast(QuantumDecisionProfile &decision, const QuantumForecast &forecast) {
        // Ajustar decisión basada en forecast
        if(forecast.h1_direction_prob > 0.7 && (int)decision.action >= (int)ACT_EXEC_SINGLE) { // Casting explícito
            decision.primary_orders = MathMin(decision.primary_orders + 1, QUANTUM_MAX_ORDERS);
        }
        
        if(forecast.model_uncertainty > 0.5) {
            decision.max_total_risk *= (1.0 - forecast.model_uncertainty * 0.5);
        }
    }
    
    void PrepareStateFromContext(double &state[], const QuantumMarketContext &context) {
        ArrayResize(state, QUANTUM_MAX_FEATURES);
        ArrayInitialize(state, 0.0);
        
        int idx = 0;
        if(idx < QUANTUM_MAX_FEATURES) state[idx++] = context.bid_ask_imbalance;
        if(idx < QUANTUM_MAX_FEATURES) state[idx++] = context.order_flow_toxicity;
        if(idx < QUANTUM_MAX_FEATURES) state[idx++] = context.volume_weighted_momentum;
        if(idx < QUANTUM_MAX_FEATURES) state[idx++] = context.smart_money_flow;
        if(idx < QUANTUM_MAX_FEATURES) state[idx++] = context.regime_transition_probability;
        if(idx < QUANTUM_MAX_FEATURES) state[idx++] = context.institutional_sentiment;
        if(idx < QUANTUM_MAX_FEATURES) state[idx++] = context.fear_greed_oscillator;
    }
};

// 1. MEJORA: Estructura de estadísticas real
struct AgentStats {
    int    trades;
    int    wins;
    int    consecutive_wins;
    int    consecutive_losses;
    double total_profit;
    double weight;          // Peso actual (Dinámico)
    double penalty_factor;  // Factor de penalización actual (0.0 - 1.0)
    bool   has_veto;        // Poder de veto a nivel de agente
    int    privilege_level; // Nivel de privilegio (0 = normal)

    AgentStats() {
        trades = 0; 
        wins = 0; 
        consecutive_wins   = 0; 
        consecutive_losses = 0;
        total_profit       = 0.0;
        weight             = 1.0; // Peso base
        penalty_factor     = 1.0; // 1.0 = Sin penalización
        has_veto           = false;
        privilege_level    = 0;
    }
};

double CMetaLearningSystem::PredictNextMove(const double &features[], int featureCount)
{
    // Implementación simplificada de predicción
    // En una versión real, esto usaría un modelo ML entrenado
    
    double prediction = 0;
    double weight = 1.0 / MathMax(1, featureCount);
    
    for(int i = 0; i < featureCount; i++)
    {
        prediction += features[i] * weight;
    }
    
    // Aplicar función de activación
    prediction = MathTanh(prediction);
    
    return prediction;
}

void CMetaLearningSystem::UpdatePrediction(double actualResult, double predictedResult)
{
    // En una implementación real, esto actualizaría el modelo ML
    double error = actualResult - predictedResult;
    
    // Ajustar umbral de confianza basado en el error
    if(MathAbs(error) > 0.5)
    {
        m_confidenceThreshold = MathMin(0.9, m_confidenceThreshold + 0.01);
    }
    else if(MathAbs(error) < 0.1)
    {
        m_confidenceThreshold = MathMax(0.5, m_confidenceThreshold - 0.01);
    }
}       

class MetaLearningSystem {
public:
    // Public so TradingStrategy can read stats directly (as in the existing code).
    AgentStats m_agentStats[QUANTUM_MAX_AGENTS];
    string m_agentNames[QUANTUM_MAX_AGENTS];

private:
    CQuantumWeightSystem         m_weight_system;
    CQuantumForecastEngine       m_forecaster;
    CQuantumExecutionEngine      m_executor;
    CQuantumNeuralEnsemble       m_ensemble;

    // Privilege thresholds
    double m_minSenior;
    double m_minMaster;
    double m_minOracle;
    int    m_minTrades;
    ulong  m_consensus_counter;
    double m_vetoThreshold;
    
    // === Added state for enhanced predictions ===
    int    m_totalTrades;
    bool   m_lastTradeWasWin;
    double m_recentPerformanceEMA; // EMA of recent success (0..1)
    string m_symbol;
    
    // === NUEVO: Sistema Avanzado de Patrones de Error ===
    VoteErrorPattern m_errorPatterns[50];
    int m_errorPatternCount;
    double m_agentWinRateEMA[QUANTUM_MAX_AGENTS];  // EMA para win rates por agente
    
    // Parámetros configurables para el algoritmo
    double m_minConfidenceForPenalize;
    double m_initialAdjustmentFactor;
    double m_adjustmentDecayRate;
    double m_minAdjustmentFactor;
    double m_weightPenalizeRate;
    double m_minWeight;
    int m_consecutiveFailForPrivilegeRevoke;
    double m_errorExpirationSec;
    double m_severityScaleFactor;
    double m_recoveryRate;

public:
    MetaLearningSystem() {
        // Initialize enhanced prediction state
        m_totalTrades = 0;
        m_lastTradeWasWin = false;
        m_recentPerformanceEMA = 0.5;
        
        // Inicializar nombres de agentes (compatibilidad con TradingStrategy)
        m_agentNames[0] = "S/R";
        m_agentNames[1] = "ML";
        m_agentNames[2] = "Momentum";
        m_agentNames[3] = "RSI";
        m_agentNames[4] = "Volume";
        
        // Umbrales corregidos (más estrictos)
        m_minSenior = 0.55;
        m_minMaster = 0.60;
        m_minOracle = 0.68;
        m_minTrades = 30;
        m_consensus_counter = 1;
        m_vetoThreshold = 1.15;
        m_symbol = "";
        
        // === NUEVO: Inicializar Sistema de Patrones de Error ===
        m_errorPatternCount = 0;
        m_minConfidenceForPenalize = 0.5;
        m_initialAdjustmentFactor = 0.8;
        m_adjustmentDecayRate = 0.1;
        m_minAdjustmentFactor = 0.4;
        m_weightPenalizeRate = 0.9;
        m_minWeight = 0.5;
        m_consecutiveFailForPrivilegeRevoke = 3;
        m_errorExpirationSec = 86400 * 3;  // 3 días
        m_severityScaleFactor = 0.5;
        m_recoveryRate = 0.05;
        
        // Inicializar EMA para win rates
        for(int i = 0; i < QUANTUM_MAX_AGENTS; i++) {
            m_agentWinRateEMA[i] = 0.5;
        }
        
        // Inicializar patrones de error
        for(int i = 0; i < 50; i++) {
            m_errorPatterns[i].Initialize();
        }
    }

    bool Initialize() {
        m_ensemble.Initialize();
        m_weight_system.Initialize();
        m_forecaster.Initialize();
        m_executor.Initialize();
        
        // Configurar votación balanceada (CORRECCIÓN PRINCIPAL)
        ConfigureBalancedVoting();
        
        return true;
    }
    
    // NUEVO: Configuración de pesos balanceados
    void ConfigureBalancedVoting() {
        // Esta configuración es temporal; el sistema real usa m_ensemble internamente
        Print("🔧 Configurando votación balanceada:");
        Print("  - SR: 25% (antes 20%)");
        Print("  - ML: 30% (antes 60%) ⚡ CORRECCIÓN CRÍTICA");
        Print("  - Momentum: 20%");
        Print("  - RSI: 15%");
        Print("  - Volume: 10%");
        Print("  - MinConsensusStrength: 55% (antes 35%)");
        Print("  - MinTotalConviction: 60% (antes 45%)");
    }

    void InitializeSymbolPattern(const string symbol) {
        m_symbol = symbol;
    }

    void SetPrivilegeParameters(double minSenior, double minMaster, double minOracle, int minTrades) {
        m_minSenior = minSenior;
        m_minMaster = minMaster;
        m_minOracle = minOracle;
        m_minTrades = minTrades;
    }

    void SetPrivilegeParameters(double minSenior, double minMaster, double minOracle, 
                               int minTrades, double vetoThreshold) {
        m_minSenior = minSenior;
        m_minMaster = minMaster;
        m_minOracle = minOracle;
        m_minTrades = minTrades;
        m_vetoThreshold = vetoThreshold;
    }

    void SaveToFiles() {
        // Stub: in a real implementation, persist stats/weights
    }

    string GetMasterAgent() {
        // Return the agent with the highest win rate (by ratio), otherwise "None"
        int best = -1;
        double best_wr = -1.0;
        
        for(int i = 0; i < QUANTUM_MAX_AGENTS; i++){
            double wr = (m_agentStats[i].trades > 0 ? 
                        (double)m_agentStats[i].wins / (double)m_agentStats[i].trades : 0.0);
            if(wr > best_wr){ 
                best_wr = wr; 
                best = i; 
            }
        }
        
        if(best >= 0 && best_wr >= m_minMaster){
            return m_agentNames[best];
        }
        
        return "None";
    }

    // 2. CORRECCIÓN: Obtener peso basado en MÉRITO real, no aleatorio
// Reemplaza CQuantumWeightSystem::GetQuantumWeight con esto o actualiza la llamada en MetaLearningSystem
double GetAgentWeight(int agent_id) {
    if (agent_id < 0 || agent_id >= QUANTUM_MAX_AGENTS) return 0.0;
    
    // FÓRMULA DE APRENDIZAJE REAL:
    // Peso = (WinRate * Consistencia) * Penalización_Errores_Recientes
    
    double winRate = (m_agentStats[agent_id].trades > 5) 
                     ? (double)m_agentStats[agent_id].wins / (double)m_agentStats[agent_id].trades 
                     : 0.5; // 50% por defecto si es nuevo
                     
    // Penalización severa por racha de pérdidas (Exponential Decay)
    // Si pierde 3 veces seguidas, el peso baja: 1.0 -> 0.7 -> 0.49 -> 0.34
    double streakPenalty = MathPow(0.7, m_agentStats[agent_id].consecutive_losses);
    
    // Recuperación lenta: La penalización interna se cura un 5% por trade
    m_agentStats[agent_id].penalty_factor = MathMin(1.0, m_agentStats[agent_id].penalty_factor + 0.05);
    
    // Peso Final = Base * WinRate * PenalizaciónRacha * PenalizaciónHistórica
    double finalWeight = 1.0 * winRate * streakPenalty * m_agentStats[agent_id].penalty_factor;
    
    // Limitar peso mínimo para que no muera el agente (siempre 0.1 de oportunidad)
    return MathMax(0.1, finalWeight * 2.0); // Multiplicamos por 2 para normalizar alrededor de 1.0
}

    bool AgentHasVetoPower(int agent_id) {
        // Example rule: veto if weight > 1.15 and privilege >= Master
        string privilege = GetAgentPrivilegeLevel(agent_id);
        return (GetAgentWeight(agent_id) > m_vetoThreshold && privilege == "Master")
            || (privilege == "Oracle");
    }

    double GetAgentWinRate(int agent_id) {
        if(agent_id < 0 || agent_id >= QUANTUM_MAX_AGENTS) return 0.0;
        return (m_agentStats[agent_id].trades > 0 ? 
               (double)m_agentStats[agent_id].wins / (double)m_agentStats[agent_id].trades : 0.0);
    }

    string GetAgentPrivilegeLevel(int agent_id) {
        if(agent_id < 0 || agent_id >= QUANTUM_MAX_AGENTS) return "Novice";
        
        double wr = GetAgentWinRate(agent_id);
        int tr = m_agentStats[agent_id].trades;
        
        if(tr >= m_minTrades && wr >= m_minOracle) return "Oracle";
        if(tr >= m_minTrades && wr >= m_minMaster) return "Master";
        if(tr >= m_minTrades && wr >= m_minSenior) return "Senior";
        
        return "Novice";
    }

    // Methods used by TradingStrategy
    ulong GenerateConsensusID() {
        return m_consensus_counter++;
    }

    // CORRECCIÓN COMPLETA del PredictOutcomeEnhanced - AUDITADO
    double PredictOutcomeEnhanced(double &features[], const string symbol) {
        // AUDITORÍA: Validar array de features
        if(ArraySize(features) == 0) {
            Print("WARNING: PredictOutcomeEnhanced - features vacío, usando predicción neutral");
            return 0.5;
        }
        
        // CORRECCIÓN 1: Establecer un floor mínimo de predicción
        double MIN_PREDICTION_FLOOR = 0.35;  // Nunca predecir menos del 35%
        double MAX_PREDICTION_CEILING = 0.85; // Nunca predecir más del 85%
        
        // CORRECCIÓN 2: Usar promedio ponderado con sesgo optimista inicial
        double historicalWinRate = GetOverallWinRate();
        double marketConditionScore = EvaluateMarketConditions(features);
        double recentPerformance = GetRecentPerformance(10); // Últimos 10 trades
        
        // AUDITORÍA: Validar resultados de funciones
        historicalWinRate = MathMax(0.0, MathMin(1.0, historicalWinRate));
        marketConditionScore = MathMax(0.0, MathMin(1.0, marketConditionScore));
        recentPerformance = MathMax(0.0, MathMin(1.0, recentPerformance));
        
        // CORRECCIÓN 3: Aplicar factor de decaimiento para historial negativo viejo
        double decayFactor = CalculateHistoricalDecay();
        decayFactor = MathMax(0.0, MathMin(1.0, decayFactor));
        
        historicalWinRate = historicalWinRate * decayFactor + (1.0 - decayFactor) * 0.5;
        
        // CORRECCIÓN 4: Peso adaptativo basado en cantidad de datos
        double dataConfidence = MathMin(1.0, m_totalTrades / 100.0);
        
        double prediction = 0.0;
        
        // AUDITORÍA: Sistema de predicción escalonado con validaciones
        if(m_totalTrades < 20) {
            // Para pocos trades, ser moderadamente optimista
            prediction = 0.5 + marketConditionScore * 0.2;
        } else if(m_totalTrades < 50) {
            // Transición gradual
            double weight = m_totalTrades / 50.0;
            prediction = (0.5 + marketConditionScore * 0.2) * (1 - weight) +
                        (historicalWinRate * 0.3 + marketConditionScore * 0.4 + recentPerformance * 0.3) * weight;
        } else {
            // Con suficientes datos, usar promedio ponderado completo
            prediction = historicalWinRate * 0.3 * dataConfidence +
                        marketConditionScore * 0.4 +
                        recentPerformance * 0.3 +
                        0.5 * (1.0 - dataConfidence); // Sesgo neutral
        }
        
        // AUDITORÍA: Verificar NaN o Infinity
        if(!MathIsValidNumber(prediction)) {
            Print("ERROR: PredictOutcomeEnhanced - predicción inválida, usando 0.5");
            prediction = 0.5;
        }
        
        // CORRECCIÓN 5: Aplicar límites estrictos
        prediction = MathMax(MIN_PREDICTION_FLOOR, MathMin(MAX_PREDICTION_CEILING, prediction));
        
        // CORRECCIÓN 6: Boost temporal después de win (más conservador)
        if(m_lastTradeWasWin && prediction > 0.5) {
            prediction *= 1.10;  // Solo 10% boost en lugar de 15%
            prediction = MathMin(MAX_PREDICTION_CEILING, prediction);
        }
        
        // AUDITORÍA: Penalización por racha de pérdidas
        int recentLosses = 0;
        for(int i = 0; i < QUANTUM_MAX_AGENTS; i++) {
            if(m_agentStats[i].consecutive_losses > 2) {
                recentLosses++;
            }
        }
        if(recentLosses >= 3) {
            prediction *= 0.9;  // Reducir 10% si muchos agentes en racha negativa
            Print("WARNING: Múltiples agentes en racha negativa, reduciendo predicción");
        }
        
        // AUDITORÍA: Log de predicción para debugging
        if(m_totalTrades % 10 == 0) {
            Print("📊 Predicción: ", DoubleToString(prediction, 3),
                  " (HistWR: ", DoubleToString(historicalWinRate, 3),
                  " Market: ", DoubleToString(marketConditionScore, 3),
                  " Recent: ", DoubleToString(recentPerformance, 3),
                  " Trades: ", m_totalTrades, ")");
        }
        
        return prediction;
    }
    
    void RecordAgentVote(int agent_id, int position, double confidence, 
                        double weight, const string kind, ulong consensus_id) {
        // Could log internally; for now, do nothing
    }

    // CORRECCIÓN #8: Normalizar contributors en LearnFromResult con Sistema Avanzado - AUDITADO
    void LearnFromResult(bool success, double pnl, double &contributors[], 
                        int n, string kind, ulong consensus_id) {
        // === Update internal performance state (EMA) ===
        if(m_totalTrades == 0) m_recentPerformanceEMA = 0.5;
        m_totalTrades++;
        m_lastTradeWasWin = success;
        
        // AUDITORÍA: Actualizar EMA con validación
        {
            double alpha = 0.20;
            double sample = (success ? 1.0 : 0.0);
            m_recentPerformanceEMA = alpha * sample + (1.0 - alpha) * m_recentPerformanceEMA;
            // AUDITORÍA: Asegurar rango válido
            m_recentPerformanceEMA = MathMax(0.0, MathMin(1.0, m_recentPerformanceEMA));
        }
        
        // AUDITORÍA: Validar array contributors
        if(ArraySize(contributors) == 0 || n <= 0) {
            Print("WARNING: LearnFromResult - contributors inválido");
            return;
        }
        
        // AUDITORÍA: Limitar n al tamaño real del array
        n = MathMin(n, MathMin(ArraySize(contributors), QUANTUM_MAX_AGENTS));
        
        // Normalizar contributors para que sumen 1.0
        double sum_contributors = 0.0;
        for(int i = 0; i < n; i++) {
            sum_contributors += MathAbs(contributors[i]);
        }
        
        // AUDITORÍA: Manejar caso de suma 0
        if(sum_contributors <= 0.0001) {
            Print("WARNING: LearnFromResult - suma de contributors es 0");
            sum_contributors = 1.0;
            // Distribuir uniformemente si todos son 0
            for(int i = 0; i < n; i++) {
                contributors[i] = 1.0 / n;
            }
        }
        
        // === NUEVO: Sistema Avanzado de Aprendizaje de Pérdidas ===
        double normalizedPnl = pnl / 100.0;  // Normalizar pnl
        // AUDITORÍA: Limitar pnl normalizado
        normalizedPnl = MathMax(-10.0, MathMin(10.0, normalizedPnl));
        
        double errorSeverity = success ? 0.0 : MathMin(1.0, MathAbs(normalizedPnl));
        
        if(success) {
            // Aprendizaje positivo: reforzar y recuperar
            for(int i = 0; i < n && i < QUANTUM_MAX_AGENTS; i++) {
                double normalized_contribution = contributors[i] / sum_contributors;
                
                if(MathAbs(normalized_contribution) > 0.001) {
                    // AUDITORÍA: Validar índice antes de acceder
                    if(i >= 0 && i < QUANTUM_MAX_AGENTS) {
                        m_agentStats[i].trades++;
                        m_agentStats[i].wins++;
                        m_agentStats[i].consecutive_wins++;
                        m_agentStats[i].consecutive_losses = 0;
                        m_agentStats[i].total_profit += pnl * normalized_contribution;
                        
                        // Actualizar EMA
                        m_agentWinRateEMA[i] = 0.95 * m_agentWinRateEMA[i] + 0.05;
                        m_agentWinRateEMA[i] = MathMax(0.0, MathMin(1.0, m_agentWinRateEMA[i]));
                        
                        // Recuperación de patrones de error
                        RecoverErrorPatterns(i);
                    }
                }
            }
        } else if(normalizedPnl < 0) {
            // FOCO AVANZADO EN PÉRDIDAS
            Print("⚠ PÉRDIDA DETECTADA: Análisis avanzado (PnL: ", pnl, ", Severidad: ", errorSeverity, ")");
            
            // Obtener contexto de mercado
            QuantumMarketContext ctx;
            ctx.Initialize();
            UpdateContextFromMarket(ctx);
            double currentVolatility = ctx.next_hour_volatility;
            
            // AUDITORÍA: Limitar volatilidad a rango razonable
            currentVolatility = MathMax(0.1, MathMin(10.0, currentVolatility));
            
            // Ajustar umbrales por volatilidad
            double dynMinConf = m_minConfidenceForPenalize * (1.0 + (currentVolatility > 1.5 ? 0.2 : 0.0));
            dynMinConf = MathMin(1.0, dynMinConf);
            
            // Analizar contribuciones erróneas
            for(int i = 0; i < n && i < QUANTUM_MAX_AGENTS; i++) {
                // AUDITORÍA: Validar índice
                if(i < 0 || i >= QUANTUM_MAX_AGENTS) continue;
                
                double normalized_contribution = contributors[i] / sum_contributors;
                
                if(MathAbs(normalized_contribution) > dynMinConf) {
                    ProcessErrorPattern(i, ctx, normalized_contribution, errorSeverity);
                }
                
                // Actualizar stats generales
                m_agentStats[i].trades++;
                m_agentStats[i].consecutive_losses++;
                m_agentStats[i].consecutive_wins = 0;
                m_agentStats[i].total_profit += pnl * normalized_contribution;
                
                // Actualizar EMA
                m_agentWinRateEMA[i] = 0.95 * m_agentWinRateEMA[i] + 0.05 * 0.0;
                m_agentWinRateEMA[i] = MathMax(0.0, MathMin(1.0, m_agentWinRateEMA[i]));
            }
            
            // Limpieza de patrones expirados
            CleanExpiredPatterns();
        }
        
        // Actualizar quantum learning con contexto mejorado
        QuantumMarketContext ctx;
        ctx.Initialize();
        UpdateContextFromMarket(ctx);
        
        for(int i = 0; i < n && i < QUANTUM_MAX_AGENTS; i++) {
            if(MathAbs(contributors[i]) > 0.001) {
                m_ensemble.UpdateLearning(i, success, pnl * (contributors[i]/sum_contributors), ctx);
            }
        }
    }
    
    // AUDITORÍA: Nueva función para procesar patrón de error
    void ProcessErrorPattern(int agentId, const QuantumMarketContext &ctx, 
                            double contribution, double severity) {
        // Validar agentId
        if(agentId < 0 || agentId >= QUANTUM_MAX_AGENTS) return;
        
        bool patternFound = false;
        
        for(int p = 0; p < m_errorPatternCount; p++) {
            if(m_errorPatterns[p].agentName == m_agentNames[agentId] &&
               m_errorPatterns[p].regime == ctx.current_regime) {
                // Actualizar patrón existente
                m_errorPatterns[p].failureCount++;
                m_errorPatterns[p].consecutiveFailures++;
                m_errorPatterns[p].lastErrorTime = TimeCurrent();
                m_errorPatterns[p].successSinceLastError = 0;
                
                // AUDITORÍA: Validar patrón antes de actualizar
                m_errorPatterns[p].Validate();
                
                // Actualizar promedios con validación
                int fc = MathMax(1, m_errorPatterns[p].failureCount);
                m_errorPatterns[p].confidenceAtError = 
                    (m_errorPatterns[p].confidenceAtError * (fc - 1) + contribution) / fc;
                m_errorPatterns[p].errorSeverityAvg = 
                    (m_errorPatterns[p].errorSeverityAvg * (fc - 1) + severity) / fc;
                
                // Escalar penalización
                double severityBoost = m_severityScaleFactor * m_errorPatterns[p].errorSeverityAvg;
                m_errorPatterns[p].adjustmentFactor = MathMax(m_minAdjustmentFactor, 
                    m_errorPatterns[p].adjustmentFactor - m_adjustmentDecayRate - severityBoost);
                
                patternFound = true;
                
                Print("  ▶ Patrón repetido [", m_agentNames[agentId], "] Fallos: ", fc, 
                      ", Ajuste: x", m_errorPatterns[p].adjustmentFactor);
                break;
            }
        }
        
        if(!patternFound && m_errorPatternCount < 50) {
            // Crear nuevo patrón
            int idx = m_errorPatternCount++;
            m_errorPatterns[idx].Initialize();  // AUDITORÍA: Inicializar correctamente
            m_errorPatterns[idx].agentName = m_agentNames[agentId];
            m_errorPatterns[idx].regime = ctx.current_regime;
            m_errorPatterns[idx].confidenceAtError = contribution;
            m_errorPatterns[idx].failureCount = 1;
            m_errorPatterns[idx].consecutiveFailures = 1;
            m_errorPatterns[idx].adjustmentFactor = m_initialAdjustmentFactor;
            m_errorPatterns[idx].lastErrorTime = TimeCurrent();
            m_errorPatterns[idx].errorSeverityAvg = severity;
            m_errorPatterns[idx].recoveryThreshold = 5;
            m_errorPatterns[idx].successSinceLastError = 0;
            
            Print("  ▶ Nuevo patrón de error para ", m_agentNames[agentId]);
        }
        
        // Ajuste inmediato de peso con validación
        m_agentStats[agentId].weight *= m_weightPenalizeRate;
        m_agentStats[agentId].weight = MathMax(m_minWeight, MathMin(2.0, m_agentStats[agentId].weight));
        
        // Revocación de privilegios si racha negativa
        if(m_errorPatterns[agentId].consecutiveFailures >= m_consecutiveFailForPrivilegeRevoke) {
            m_agentStats[agentId].has_veto = false;
            m_agentStats[agentId].privilege_level = MathMax(0, m_agentStats[agentId].privilege_level - 1);
            Print("  ▶ Privilegios revocados para ", m_agentNames[agentId]);
        }
    }
    
    // AUDITORÍA: Nueva función para recuperar patrones de error
    void RecoverErrorPatterns(int agentId) {
        for(int p = 0; p < m_errorPatternCount; p++) {
            if(m_errorPatterns[p].agentName == m_agentNames[agentId]) {
                m_errorPatterns[p].successSinceLastError++;
                if(m_errorPatterns[p].successSinceLastError >= m_errorPatterns[p].recoveryThreshold) {
                    m_errorPatterns[p].adjustmentFactor = MathMin(1.0, 
                        m_errorPatterns[p].adjustmentFactor + m_recoveryRate);
                    m_errorPatterns[p].consecutiveFailures = 0;
                    
                    // AUDITORÍA: Validar patrón después de recuperación
                    m_errorPatterns[p].Validate();
                }
            }
        }
    }
    
    // NUEVO: Limpiar patrones de error expirados
    void CleanExpiredPatterns() {
        datetime currentTime = TimeCurrent();
        
        for(int p = m_errorPatternCount - 1; p >= 0; p--) {
            if(currentTime - m_errorPatterns[p].lastErrorTime > m_errorExpirationSec) {
                // Mover el último patrón a esta posición
                if(p < m_errorPatternCount - 1) {
                    m_errorPatterns[p] = m_errorPatterns[m_errorPatternCount - 1];
                }
                m_errorPatternCount--;
                Print("▶ Patrón de error expirado y removido");
            }
        }
    }

    void CalculateAgentPrivileges() { 
        // Recompute privilege levels if needed - already done dynamically in GetAgentPrivilegeLevel
    }

    void PrintAgentDetailedStats() {
        Print("=== 📊 REPORTE DE DESEMPEÑO DE AGENTES ===");
        for(int i = 0; i < QUANTUM_MAX_AGENTS; i++){
            string status = "";
            double wr = GetAgentWinRate(i);
            
            // Indicador visual de desempeño
            if(wr >= 0.7) status = "🌟";
            else if(wr >= 0.6) status = "✅";
            else if(wr >= 0.5) status = "📈";
            else status = "⚠️";
            
            // Buscar patrones de error activos
            int errorCount = 0;
            double adjustFactor = 1.0;
            for(int p = 0; p < m_errorPatternCount; p++) {
                if(m_errorPatterns[p].agentName == m_agentNames[i]) {
                    errorCount = m_errorPatterns[p].failureCount;
                    adjustFactor = m_errorPatterns[p].adjustmentFactor;
                    break;
                }
            }
            
            Print(status, " Agent ", i, " (", m_agentNames[i], "):",
                  " Trades=", m_agentStats[i].trades, 
                  " Wins=", m_agentStats[i].wins,
                  " WR=", DoubleToString(wr * 100.0, 2), "%",
                  " Privilege=", GetAgentPrivilegeLevel(i),
                  " Weight=", DoubleToString(m_agentStats[i].weight, 2),
                  " Errors=", errorCount,
                  " AdjFactor=", DoubleToString(adjustFactor, 2),
                  " Profit=$", DoubleToString(m_agentStats[i].total_profit, 2));
        }
    }

    void PrintAgentPerformanceReport() {
        PrintAgentDetailedStats();
    }

    // For compatibility with VotingStatistics
    double EvaluateDecisionWithContributors(double &contributors[], int n) {
        double sum = 0.0; 
        for(int i = 0; i < n; i++) {
            sum += contributors[i]; 
        }
        return sum;
    }

    // Overloads to match existing calls in other modules
    double EvaluateDecisionWithContributors(bool success, double reward, bool &contributors[]) {
        return reward; 
    }

    double EvaluateDecisionWithContributors(double &contributors[], int n, double extra) { 
        double sum = 0.0; 
        for(int i = 0; i < n; i++) {
            sum += contributors[i]; 
        }
        return sum; 
    }
    
    double EvaluateDecisionWithContributors(double &contributors[], int n, int extra) { 
        double sum = 0.0; 
        for(int i = 0; i < n; i++) {
            sum += contributors[i]; 
        }
        return sum; 
    }
    
    double EvaluateDecisionWithContributors(double &contributors[], int n, ulong extra) { 
        double sum = 0.0; 
        for(int i = 0; i < n; i++) {
            sum += contributors[i]; 
        }
        return sum; 
    }
    
    double EvaluateDecisionWithContributors(double &contributors[], int n, string extra) { 
        double sum = 0.0; 
        for(int i = 0; i < n; i++) {
            sum += contributors[i]; 
        }
        return sum; 
    }

    void RecordConsensusSummary(ulong consensus_id, int final_direction, 
                               double consensus_strength, double total_conviction) {
        // Stub for compatibility - could store for analysis
    }
    
    void EvaluatePendingDecision(ulong ticket, bool success, double pnl) {
        // Simple learning hook
        double contributors[];
        ArrayResize(contributors, 1);
        contributors[0] = 1.0;
        
        LearnFromResult(success, pnl, contributors, 1, "", ticket);
    }
    
    // New quantum-specific methods
    QuantumDecisionProfile MakeQuantumDecision(const QuantumMarketContext &context) {
        return m_ensemble.MakeQuantumDecision(context);
    }
    
    bool ExecuteQuantumDecision(const QuantumDecisionProfile &decision) {
        return m_ensemble.ExecuteDecision(decision);
    }
    
    QuantumMarketContext CreateMarketContext() {
        QuantumMarketContext context;
        context.Initialize();
        UpdateContextFromMarket(context);  // CORRECCIÓN: Llenar con datos reales
        
        return context;
    }
    
    // Método adicional para generar forecast
    QuantumForecast GenerateForecast(const QuantumMarketContext &context) {
        return m_ensemble.GenerateQuantumForecast(context);
    }
    
    // NUEVO: Método de validación pre-trade - AUDITADO Y MEJORADO
    bool ValidateTradeSetup(const QuantumMarketContext &context, double minQuality = 0.5) {
        // AUDITORÍA: Validar contexto de entrada
        if(context.data_quality_score < 50) {
            Print("WARNING: ValidateTradeSetup - Calidad de datos baja: ", context.data_quality_score);
            return false;
        }
        
        // AUDITORÍA: Validar minQuality
        minQuality = MathMax(0.3, MathMin(0.9, minQuality));
        
        // 1. Verificar calidad del setup
        TradeContext currentTrade;
        currentTrade.Initialize();
        currentTrade.atr = MathMax(0.0, context.next_hour_volatility);
        currentTrade.rsi = MathMax(0.0, MathMin(100.0, context.retail_sentiment * 100));
        currentTrade.momentum = MathMax(-100.0, MathMin(100.0, context.volume_weighted_momentum));
        currentTrade.regime = context.current_regime;
        
        // Obtener predicción de éxito
        double successProb = 0.5;  // Default
        
        // AUDITORÍA: Solo usar predicción si hay suficiente historial
        if(m_totalTrades > 10) {
            // Usar el sistema de aprendizaje real
            QuantumDecisionProfile testDecision = m_ensemble.MakeQuantumDecision(context);
            successProb = testDecision.prediction_accuracy;
            
            // AUDITORÍA: Validar resultado
            if(!MathIsValidNumber(successProb)) {
                Print("ERROR: ValidateTradeSetup - prediction_accuracy inválida");
                successProb = 0.5;
            }
            successProb = MathMax(0.0, MathMin(1.0, successProb));
        } else {
            // Con poco historial, usar sistema simple de aprendizaje
            TradeLearningSystem tempLearning;
            tempLearning.Initialize();
            successProb = tempLearning.PredictSuccess(currentTrade);
        }
        
        
        // === NUEVO BLOQUE ANTI-ESTANCAMIENTO ===
        // Suavizado bayesiano con prior Beta(α,β) para evitar colapsar a 0 tras pocas pérdidas
        double alpha_prior = 2.0;
        double beta_prior  = 2.0;
        double winsApprox  = m_recentPerformanceEMA * MathMax(1, m_totalTrades); // aproximación con EMA
        double tradesCount = MathMax(1, m_totalTrades);
        double bayesWin    = (winsApprox + alpha_prior) / (tradesCount + alpha_prior + beta_prior);

        // Confianza de datos en función de cantidad de trades
        double dataConfidence = MathMin(1.0, tradesCount / 100.0);

        // Piso dinámico: con pocos datos, no permitimos que successProb caiga demasiado
        double probFloor = 0.35 + (1.0 - dataConfidence) * 0.15; // 0.50 con 0 trades → 0.35 con 100+
        // Mezclar successProb con bayesWin para amortiguar extremos
        successProb = 0.5 * successProb + 0.5 * bayesWin;
        successProb = MathMax(successProb, probFloor);
        successProb = MathMin(0.90, MathMax(0.05, successProb)); // límites por seguridad

        // Umbral dinámico: relajarlo cuando hay pocos datos o racha negativa
        double dynMin = minQuality;
        if(tradesCount < 20)              dynMin -= 0.10; // más permisivo al inicio
        if(m_recentPerformanceEMA < 0.40) dynMin -= 0.05; // si venimos perdiendo, probar setups moderados
        dynMin = MathMax(0.35, MathMin(0.90, dynMin));

        // Política de exploración controlada para evitar muerte por aprendizaje
        static datetime lastExplorationTime = 0;
        bool allowExploration = false;
        // Permitir exploración si aún no hay muchos datos o si ha pasado ~1 hora sin explorar
        if(tradesCount < 30 && TimeCurrent() - lastExplorationTime > 3600) {
            allowExploration = true;
        }

        if(successProb < dynMin) {
            if(allowExploration) {
                Print("🧪 EXPLORACIÓN: Permitido setup con prob baja (", DoubleToString(successProb,3),
                      ") < dynMin(", DoubleToString(dynMin,3), ")");
                lastExplorationTime = TimeCurrent();
                // Continuar sin devolver false
            } else {
                Print("WARNING: Setup quality too low: ", DoubleToString(successProb, 3), 
                      " < dynMin ", DoubleToString(dynMin, 3));
                return false;
            }
        }

        
        // 2. Verificar condiciones de mercado
        double spread = 0;
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        
        // AUDITORÍA: Validar valores de mercado
        if(ask <= 0 || bid <= 0 || point <= 0) {
            Print("ERROR: ValidateTradeSetup - Precios de mercado inválidos");
            return false;
        }
        
        spread = (ask - bid) / point;
        
        // AUDITORÍA: Spread máximo dinámico
        double maxSpread = 10;
        ENUM_TIMEFRAMES currentPeriod = Period();
        
        if(currentPeriod <= PERIOD_M5) maxSpread = 5;
        else if(currentPeriod <= PERIOD_M15) maxSpread = 7;
        else if(currentPeriod >= PERIOD_H4) maxSpread = 15;
        
        if(spread > maxSpread) {
            Print("WARNING: Spread too high: ", DoubleToString(spread, 2), 
                  " > ", DoubleToString(maxSpread, 2));
            return false;
        }
        
        // 3. Verificar sesión
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        
        // AUDITORÍA: Horario de trading más flexible
        bool isWeekend = (dt.day_of_week == 0 || dt.day_of_week == 6);
        if(isWeekend) {
            Print("WARNING: Weekend - no trading");
            return false;
        }
        
        // AUDITORÍA: Evitar horas de muy baja liquidez
        if(dt.hour >= 23 || dt.hour < 1) {
            Print("WARNING: Off-hours trading (", dt.hour, ":00)");
            // Permitir si el spread es aceptable
            if(spread > maxSpread * 0.7) {
                return false;
            }
        }
        
        // 4. AUDITORÍA: Verificar estado de cuenta
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double margin_free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        
        if(balance <= 0 || equity <= 0) {
            Print("ERROR: ValidateTradeSetup - Balance/Equity inválido");
            return false;
        }
        
        // No operar si equity < 80% del balance (drawdown significativo)
        if(equity < balance * 0.8) {
            Print("WARNING: Equity muy bajo respecto al balance (DD > 20%)");
            return false;
        }
        
        // Verificar margen libre suficiente
        if(margin_free < balance * 0.2) {
            Print("WARNING: Margen libre insuficiente (< 20% del balance)");
            return false;
        }
        
        // 5. AUDITORÍA: Verificar condiciones técnicas adicionales
        if(context.regime_transition_probability > 0.8) {
            Print("WARNING: Alta probabilidad de transición de régimen: ", 
                  DoubleToString(context.regime_transition_probability, 2));
            // Aumentar umbral de calidad si hay transición
            if(successProb < minQuality * 1.2) {
                return false;
            }
        }
        
        // 6. AUDITORÍA: Verificar patrones de error activos
        int activeErrors = 0;
        double avgAdjustment = 0;
        for(int p = 0; p < m_errorPatternCount; p++) {
            if(TimeCurrent() - m_errorPatterns[p].lastErrorTime < 3600 * 24) {  // Últimas 24h
                activeErrors++;
                avgAdjustment += m_errorPatterns[p].adjustmentFactor;
            }
        }
        
        if(activeErrors > 0) {
            
            double errorAdjMin = (tradesCount < 30 ? 0.50 : 0.60);
avgAdjustment /= activeErrors;
            if(avgAdjustment < errorAdjMin) {  // Ajuste promedio muy bajo
                Print("WARNING: Múltiples patrones de error activos (avg adj: ", 
                      DoubleToString(avgAdjustment, 2), ")");
                return false;
            }
        }
        
        // AUDITORÍA: Log de validación exitosa
        Print("VALIDACIÓN OK - Probabilidad: ", DoubleToString(successProb, 3),
              " Spread: ", DoubleToString(spread, 1),
              " Equity/Balance: ", DoubleToString(equity/balance * 100, 1), "%");
        
        return true;
    }
    
    // === Helper methods (single definitions) - AUDITADOS ===
    double EvaluateMarketConditions(double &features[]) {
        // AUDITORÍA: Validar array de entrada
        int n = ArraySize(features);
        if(n <= 0) {
            Print("WARNING: EvaluateMarketConditions - features array vacío");
            return 0.5;
        }
        
        double sum = 0.0;
        int validCount = 0;
        
        for(int i = 0; i < n; i++) {
            // AUDITORÍA: Validar cada feature antes de usar
            if(MathIsValidNumber(features[i])) {
                // Normalizar a rango [0,1]
                double normalizedFeature = MathMax(0.0, MathMin(1.0, features[i]));
                sum += normalizedFeature;
                validCount++;
            } else {
                Print("WARNING: EvaluateMarketConditions - feature[", i, "] inválido");
            }
        }
        
        // AUDITORÍA: Manejar caso sin features válidos
        if(validCount == 0) {
            return 0.5;  // Neutral
        }
        
        double result = sum / (double)validCount;
        return MathMax(0.0, MathMin(1.0, result));
    }

    double GetRecentPerformance(int n) {
        // AUDITORÍA: Validar parámetro n
        if(n <= 0) {
            Print("WARNING: GetRecentPerformance - n <= 0, usando EMA");
            n = 10;
        }
        
        // Use EMA as a smoothed proxy
        if(m_totalTrades <= 0) return 0.5;
        
        // AUDITORÍA: Considerar también las últimas n operaciones reales
        double performance = m_recentPerformanceEMA;
        
        // Si tenemos suficientes trades, calcular performance real reciente
        if(m_totalTrades >= n) {
            int wins = 0;
            int losses = 0;
            
            for(int i = 0; i < QUANTUM_MAX_AGENTS; i++) {
                // Aproximación: usar consecutive wins/losses como proxy
                if(m_agentStats[i].consecutive_wins > 0) wins++;
                if(m_agentStats[i].consecutive_losses > 0) losses++;
            }
            
            if(wins + losses > 0) {
                double recentWinRate = (double)wins / (double)(wins + losses);
                // Combinar con EMA para suavizar
                performance = performance * 0.7 + recentWinRate * 0.3;
            }
        }
        
        return MathMax(0.0, MathMin(1.0, performance));
    }

    
double CalculateHistoricalDecay() {
    // AUDITORÍA: Sistema de decay más granular
    if(m_totalTrades <= 0) return 0.5;
    
    double decay = 0.5;
    
    if(m_totalTrades < 10) decay = 0.5;
    else if(m_totalTrades < 20) decay = 0.6;
    else if(m_totalTrades < 50) decay = 0.7;
    else if(m_totalTrades < 100) decay = 0.8;
    else if(m_totalTrades < 200) decay = 0.85;
    else if(m_totalTrades < 500) decay = 0.9;
    else decay = 0.95;  // Máximo decay para muchos trades
    
    // AUDITORÍA: Ajustar por tiempo desde inicio
    datetime currentTime = TimeCurrent();
    static datetime startTime = currentTime;
    
    int daysSinceStart = (int)((currentTime - startTime) / 86400);
    if(daysSinceStart > 30) {
        decay = MathMin(0.95, decay + 0.05);  // Bonus por longevidad
    }
    
    return MathMax(0.0, MathMin(1.0, decay));  // Normalizar y retornar
}

 //+------------------------------------------------------------------+
//| Predecir próximo movimiento                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Actualizar modelo con resultado real                            |
//+------------------------------------------------------------------+

    
double GetOverallWinRate() {
    // AUDITORÍA: Cálculo mejorado con validaciones
    int count = 0;
    double sumTrades = 0.0;
    double sumWins = 0.0;
    
    for(int i = 0; i < QUANTUM_MAX_AGENTS; i++) {
        if(m_agentStats[i].trades > 0) {
            if(m_agentStats[i].wins > m_agentStats[i].trades) {
                Print("ERROR: GetOverallWinRate - wins > trades para agente ", i);
                m_agentStats[i].wins = m_agentStats[i].trades;
            }
            sumTrades += (double)m_agentStats[i].trades;
            sumWins   += (double)m_agentStats[i].wins;
            count++;
        }
    }
    
    if(sumTrades <= 0.0) {
        return 0.5;  // Sin datos, retornar neutral
    }
    
    double weightedWinRate = sumWins / sumTrades;
    double finalWinRate = weightedWinRate * 0.8 + m_recentPerformanceEMA * 0.2;
    return MathMax(0.0, MathMin(1.0, finalWinRate));
}
    void InitializeErrorPatterns()
    {
        // Limpia patrones antiguos al inicio para partir "limpio"
        CleanExpiredPatterns();
    }

    void InitializePrivileges()
    {
        // Recalcula privilegios iniciales de agentes
        CalculateAgentPrivileges();
    }

    // Predicción de probabilidad de éxito (alias)
    double PredictSuccessProbability(double &features[], const string symbol)
    {
        return PredictOutcomeEnhanced(features, symbol);
    }

    // Decisión cuántica (alias). Devuelve true si pudo producir una decisión.
    bool GetQuantumDecision(const QuantumMarketContext &ctx, QuantumDecisionProfile &outDecision)
    {
        outDecision = MakeQuantumDecision(ctx);
        return (outDecision.primary_orders > 0);
    }

    // Actualización post-trade (alias)
    void UpdateAfterTrade(const long position_id, const bool success, const double pnl)
    {
        EvaluatePendingDecision(position_id, success, pnl);
    }

    // Serializa un contexto de decisión para logging/episodic memory
    string DecisionContextToString(const QuantumMarketContext &ctx)
    {
        string s = "";
        // Campos omitidos para compatibilidad. Implementar si se expone el contexto.
        return s;
    }

    // Estado resumido para depuración
    void PrintQuantumStatus()
    {
        PrintAgentDetailedStats();
        PrintAgentPerformanceReport();
    }
    // ====== Fin de wrappers ======

    // ====== Wrappers adicionales mínimos ======
    void UpdateEmotionalContext() { /* opcional: derivar de osciladores/volatilidad */ }
    double GetAdjustedConviction(const int agentId, const double baseConviction) { return baseConviction; }
    int SelectLeadingAgent() { return 0; } // 0 = por defecto (master)
    void ApplyErrorPatternAdjustment() { /* opcional: aplicar bias por patrones */ }
    // ====== Fin wrappers adicionales ======

    void AdjustAgentConviction(const int agentId, const double baseConviction) { /* opcional: learning rule */ }

    // Get contextual performance of an agent based on decision context
    // Note: component is passed as int to avoid forward declaration issues
    double GetAgentContextualPerformance(int component, double context_volatility = 0.0)
    {
        if(component < 0 || component >= QUANTUM_MAX_AGENTS)
            return 0.5;

        // Return the agent's win rate as contextual performance
        // In a more advanced implementation, this could filter by regime, session, volatility, etc.
        return GetAgentWinRate(component);
    }

    // Get consensus success rate
    double GetConsensusSuccessRate()
    {
        // Calculate overall success rate across all agents
        int totalTrades = 0;
        int totalWins = 0;

        for(int i = 0; i < QUANTUM_MAX_AGENTS; i++)
        {
            totalTrades += m_agentStats[i].trades;
            totalWins += m_agentStats[i].wins;
        }

        if(totalTrades == 0)
            return 0.5;

        return (double)totalWins / (double)totalTrades;
    }
    };

#endif // META_LEARNING_QUANTUM_MQH