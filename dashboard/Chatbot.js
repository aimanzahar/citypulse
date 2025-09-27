const { useState, useRef, useEffect } = React;

// Chatbot component that integrates with OpenRouter API
function Chatbot() {
  console.log('Chatbot component loaded successfully');
  const [config, setConfig] = useState(null);
  const [messages, setMessages] = useState([
    {
      id: 1,
      type: 'bot',
      content: 'Hello! I\'m your CityPulse assistant. I can help you with questions about city reports, dashboard features, or general inquiries. How can I assist you today?',
      timestamp: new Date()
    }
  ]);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const messagesEndRef = useRef(null);
  const inputRef = useRef(null);

  // Auto-scroll to bottom when new messages are added
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // Load configuration from environment variables
  useEffect(() => {
    // For security, API keys should never be hardcoded in frontend code
    // In production, use a backend service or build-time replacement
    const loadConfig = async () => {
      // Check if we're in development mode (localhost)
      const isDevelopment = window.location.hostname === 'localhost' ||
                           window.location.hostname === '127.0.0.1';

      if (isDevelopment) {
        // In development, load from secure backend endpoint
        console.log('Development mode detected');
        console.log('Loading configuration from backend server...');

        try {
          const response = await fetch('http://localhost:3001/api/chatbot-config');
          if (response.ok) {
            const configData = await response.json();

            // Validate that we have an API key
            if (!configData.OPENROUTER_API_KEY) {
              throw new Error('API key not found in backend configuration');
            }

            setConfig({
              OPENROUTER_API_KEY: configData.OPENROUTER_API_KEY,
              OPENROUTER_BASE_URL: configData.OPENROUTER_BASE_URL,
              OPENROUTER_MODEL: configData.OPENROUTER_MODEL
            });

            console.log('Configuration loaded from backend server successfully');
          } else {
            const errorData = await response.json();
            throw new Error(`Backend server error: ${response.status} - ${errorData.error || 'Unknown error'}`);
          }
        } catch (error) {
          console.error('Could not load configuration from backend:', error.message);
          console.log('Please make sure the Flask server is running on port 3001');
          console.log('Start the server with: python server.py');

          // Show user-friendly error message
          setTimeout(() => {
            alert('Chatbot configuration could not be loaded. Please make sure the backend server is running on port 3001.');
          }, 1000);

          // Set config to indicate backend is not available
          setConfig({
            OPENROUTER_API_KEY: null,
            OPENROUTER_BASE_URL: 'https://openrouter.ai/api/v1',
            OPENROUTER_MODEL: 'x-ai/grok-4-fast:free'
          });
        }
      } else {
        // In production, this should come from a secure backend endpoint
        console.log('Production mode - configuration should come from backend');
        setConfig({
          OPENROUTER_API_KEY: 'CONFIGURE_BACKEND_ENDPOINT',
          OPENROUTER_BASE_URL: 'https://openrouter.ai/api/v1',
          OPENROUTER_MODEL: 'x-ai/grok-4-fast:free'
        });
      }
    };

    loadConfig();
    console.log('Config loading initiated...');
  }, []);

  // Debug: Monitor config changes
  useEffect(() => {
    if (config) {
      console.log('Config loaded successfully:', {
        hasKey: !!config.OPENROUTER_API_KEY,
        baseURL: config.OPENROUTER_BASE_URL,
        model: config.OPENROUTER_MODEL
      });
    }
  }, [config]);

  // Function to clean up markdown formatting from AI responses
  const cleanMarkdown = (text) => {
    return text
      // Remove headers (### text)
      .replace(/^###\s+/gm, '')
      .replace(/^##\s+/gm, '')
      .replace(/^#\s+/gm, '')
      // Convert bold/italic (*text*) to readable format
      .replace(/\*([^*]+)\*/g, '$1')
      // Remove extra asterisks
      .replace(/\*{2,}/g, '')
      // Convert bullet points (-) to readable format
      .replace(/^- /gm, '• ')
      // Clean up multiple spaces but preserve line breaks
      .replace(/ {2,}/g, ' ')
      // Trim each line while preserving line breaks
      .split('\n')
      .map(line => line.trim())
      .join('\n')
      .trim();
  };

  // Fetch real ticket data from backend
  const fetchTicketStats = async () => {
    try {
      console.log('Fetching real ticket statistics...');
      const response = await fetch('http://localhost:3001/api/ticket-stats');

      if (response.ok) {
        const stats = await response.json();
        console.log('Real ticket stats fetched:', stats);
        return stats;
      } else {
        console.error('Failed to fetch ticket stats:', response.status);
        return null;
      }
    } catch (error) {
      console.error('Error fetching ticket stats:', error);
      return null;
    }
  };

  // Fetch tickets with location information
  const fetchTicketLocations = async (severity = 'high') => {
    try {
      console.log(`Fetching ${severity} severity ticket locations...`);
      const response = await fetch(`http://localhost:3001/api/ticket-locations?severity=${severity}`);

      if (response.ok) {
        const data = await response.json();
        console.log(`${severity} severity ticket locations fetched:`, data);

        // Debug: Check what location data looks like
        if (data && data.tickets && data.tickets.length > 0) {
          console.log('Sample ticket location_info:', data.tickets[0].location_info);
        }

        return data;
      } else {
        console.error('Failed to fetch ticket locations:', response.status, response.statusText);
        const errorText = await response.text();
        console.error('Error response:', errorText);
        return null;
      }
    } catch (error) {
      console.error('Error fetching ticket locations:', error);
      return null;
    }
  };

  // Send message to OpenRouter API
  const sendMessage = async (userMessage) => {
    if (!userMessage.trim() || isLoading) return;

    // Wait for config to be loaded
    if (!config) {
      console.log('Config not loaded yet, waiting...');
      setTimeout(() => sendMessage(userMessage), 100);
      return;
    }

    // Check if API key is available
    if (!config.OPENROUTER_API_KEY) {
      console.error('API key not available. Backend server may not be running.');
      setMessages(prev => [...prev, {
        id: Date.now() + 1,
        type: 'bot',
        content: 'Sorry, the chatbot is not properly configured. Please make sure the backend server is running on port 3001.',
        timestamp: new Date()
      }]);
      return;
    }

    console.log('Sending message with config:', {
      baseURL: config.OPENROUTER_BASE_URL,
      model: config.OPENROUTER_MODEL,
      hasKey: !!config.OPENROUTER_API_KEY
    });

    setIsLoading(true);

    try {
      // Fetch real ticket data to provide accurate context
      const ticketStats = await fetchTicketStats();

      // Fetch location information for high severity tickets
      const locationData = await fetchTicketLocations('high');

      // Debug logging for location data
      console.log('Location data fetched:', locationData);

      const requestHeaders = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.OPENROUTER_API_KEY}`,
        'HTTP-Referer': window.location.href,
        'X-Title': 'CityPulse Dashboard'
      };

      console.log('Making API request to:', `${config.OPENROUTER_BASE_URL}/chat/completions`);
      console.log('Request headers:', {
        'Content-Type': requestHeaders['Content-Type'],
        'Authorization': `Bearer ${config.OPENROUTER_API_KEY ? '[API_KEY_PRESENT]' : '[NO_KEY]'}`,
        'HTTP-Referer': requestHeaders['HTTP-Referer'],
        'X-Title': requestHeaders['X-Title']
      });

      // Create system prompt with real data
      let systemPrompt = `You are a helpful assistant for the CityPulse Dashboard - a city reporting system. You help users understand dashboard features, city reports, and provide general assistance. Keep responses concise, helpful, and use plain text without markdown formatting, headers, or special characters.`;

      // Add real data context if available
      if (ticketStats && !ticketStats.error) {
        systemPrompt += `\n\nIMPORTANT: Use the following REAL DATA from the system instead of making up information:

Current Ticket Statistics:
- Total tickets: ${ticketStats.total_tickets}
- High severity tickets: ${ticketStats.high_severity_count}
- Active tickets (submitted + in progress): ${ticketStats.active_tickets_count}
- Severity breakdown: ${JSON.stringify(ticketStats.severity_breakdown)}
- Status breakdown: ${JSON.stringify(ticketStats.status_breakdown)}
- Category breakdown: ${JSON.stringify(ticketStats.category_breakdown)}

Always use these actual numbers when answering questions about ticket counts, severity levels, or statistics. Do not hallucinate or make up different numbers.`;

        // Add location context if available
        if (locationData && locationData.tickets && locationData.tickets.length > 0) {
          console.log('Adding location context to system prompt...');
          console.log('Number of tickets with location data:', locationData.tickets.length);

          // Check if we have actual location information
          const ticketsWithValidLocations = locationData.tickets.filter(ticket =>
            ticket.location_info &&
            ticket.location_info.city &&
            ticket.location_info.city !== 'Unknown'
          );

          if (ticketsWithValidLocations.length > 0) {
            systemPrompt += `\n\nLOCATION INFORMATION for ${locationData.severity_filter.toUpperCase()} severity tickets:`;

            ticketsWithValidLocations.forEach((ticket, index) => {
              const locationInfo = ticket.location_info || {};
              const city = locationInfo.city || 'Unknown city';
              const suburb = locationInfo.suburb || '';
              const road = locationInfo.road || '';

              systemPrompt += `\nTicket ${index + 1}: ${ticket.category} in ${city}`;
              if (suburb) systemPrompt += `, ${suburb}`;
              if (road) systemPrompt += ` near ${road}`;
              systemPrompt += ` (${locationInfo.lat}, ${locationInfo.lng})`;
            });

            systemPrompt += `\n\nUse this location information when users ask about where tickets are located. Provide city/area names rather than just coordinates.`;
          } else {
            systemPrompt += `\n\nNote: Location details are currently being processed. For precise locations, direct users to check the CityPulse Dashboard map view.`;
          }
        } else {
          console.log('No location data available or location data is empty');
          systemPrompt += `\n\nNote: Location details are currently being processed. For precise locations, direct users to check the CityPulse Dashboard map view.`;
        }

        systemPrompt += ` If asked about data not available here, say you need to check the dashboard or that the information is not currently available.`;
      } else {
        systemPrompt += `\n\nNote: Real-time data is currently unavailable. Please check the dashboard for the most current information.`;
      }

      // Debug: Log the final system prompt
      console.log('Final system prompt:', systemPrompt);

      const response = await fetch(`${config.OPENROUTER_BASE_URL}/chat/completions`, {
        method: 'POST',
        headers: requestHeaders,
        body: JSON.stringify({
          model: config.OPENROUTER_MODEL,
          messages: [
            {
              role: 'system',
              content: systemPrompt
            },
            ...messages.filter(msg => msg.type !== 'system').map(msg => ({
              role: msg.type === 'user' ? 'user' : 'assistant',
              content: msg.content
            })),
            {
              role: 'user',
              content: userMessage
            }
          ],
          max_tokens: 500,
          temperature: 0.7
        })
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error('OpenRouter API error:', response.status, errorText);
        console.error('Response headers:', Object.fromEntries(response.headers.entries()));
        throw new Error(`API request failed: ${response.status} - ${errorText}`);
      }

      const data = await response.json();
      console.log('OpenRouter API response:', data);

      if (data.choices && data.choices[0] && data.choices[0].message) {
        const botResponse = cleanMarkdown(data.choices[0].message.content);

        setMessages(prev => [...prev, {
          id: Date.now() + 1,
          type: 'bot',
          content: botResponse,
          timestamp: new Date()
        }]);
      } else {
        console.error('Invalid API response format:', data);
        throw new Error('Invalid response format from API');
      }
    } catch (error) {
      console.error('Error calling OpenRouter API:', error);
      setMessages(prev => [...prev, {
        id: Date.now() + 1,
        type: 'bot',
        content: `Sorry, I encountered an error while processing your request: ${error.message}. Please try again later.`,
        timestamp: new Date()
      }]);
    } finally {
      setIsLoading(false);
    }
  };

  // Handle form submission
  const handleSubmit = (e) => {
    e.preventDefault();
    if (!inputValue.trim() || isLoading) return;

    const userMessage = inputValue.trim();
    setMessages(prev => [...prev, {
      id: Date.now(),
      type: 'user',
      content: userMessage,
      timestamp: new Date()
    }]);

    setInputValue('');
    sendMessage(userMessage);
  };

  // Handle key press
  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  // Format timestamp
  const formatTime = (date) => {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  // Quick action buttons
  const quickActions = [
    {
      label: 'Dashboard Help',
      message: 'How do I use the dashboard filters?'
    },
    {
      label: 'Report Status',
      message: 'What do the different report statuses mean?'
    },
    {
      label: 'Categories',
      message: 'What types of city issues can be reported?'
    },
    {
      label: 'Navigation',
      message: 'How do I navigate to a specific location on the map?'
    }
  ];

  const handleQuickAction = (message) => {
    setInputValue(message);
    if (inputRef.current) {
      inputRef.current.focus();
    }
  };

  if (!isOpen) {
    return (
      <div className="chatbot-toggle" onClick={() => setIsOpen(true)}>
        <div className="chatbot-toggle-icon">
          💬
        </div>
        <span>Chat Assistant</span>
      </div>
    );
  }

  return (
    <div className="chatbot-container">
      <div className="chatbot-header">
        <h3>CityPulse Assistant</h3>
        <button className="chatbot-close" onClick={() => setIsOpen(false)}>
          ×
        </button>
      </div>

      <div className="chatbot-messages">
        {messages.map((message) => (
          <div
            key={message.id}
            className={`message ${message.type}`}
          >
            <div className="message-avatar">
              {message.type === 'bot' ? '🤖' : '👤'}
            </div>
            <div className="message-content">
              <div className="message-text">{message.content}</div>
              <div className="message-time">
                {formatTime(message.timestamp)}
              </div>
            </div>
          </div>
        ))}

        {isLoading && (
          <div className="message bot">
            <div className="message-avatar">🤖</div>
            <div className="message-content">
              <div className="message-text">
                <div className="typing-indicator">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
              </div>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      <div className="chatbot-quick-actions">
        {quickActions.map((action, index) => (
          <button
            key={index}
            className="quick-action-btn"
            onClick={() => handleQuickAction(action.message)}
          >
            {action.label}
          </button>
        ))}
      </div>

      <form className="chatbot-input-form" onSubmit={handleSubmit}>
        <input
          ref={inputRef}
          type="text"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          onKeyPress={handleKeyPress}
          placeholder="Ask me anything about CityPulse..."
          disabled={isLoading}
          className="chatbot-input"
        />
        <button
          type="submit"
          disabled={!inputValue.trim() || isLoading}
          className="chatbot-send-btn"
        >
          {isLoading ? '...' : 'Send'}
        </button>
      </form>
    </div>
  );
}

// Export for use in other modules
window.Chatbot = Chatbot;
