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
    const loadConfig = () => {
      // Check if we're in development mode (localhost)
      const isDevelopment = window.location.hostname === 'localhost' ||
                           window.location.hostname === '127.0.0.1';

      if (isDevelopment) {
        // In development, try to load from environment or show setup message
        console.log('Development mode detected');
        console.log('Please ensure your .env file is properly configured');
        console.log('For security, consider using a backend service in production');

        // For now, we'll use a placeholder that should be replaced
        // In a real app, this would be handled by build tools
        setConfig({
          OPENROUTER_API_KEY: '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',
          OPENROUTER_BASE_URL: 'https://openrouter.ai/api/v1',
          OPENROUTER_MODEL: 'x-ai/grok-4-fast:free'
        });
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

  // Send message to OpenRouter API
  const sendMessage = async (userMessage) => {
    if (!userMessage.trim() || isLoading) return;

    // Wait for config to be loaded
    if (!config) {
      console.log('Config not loaded yet, waiting...');
      setTimeout(() => sendMessage(userMessage), 100);
      return;
    }

    console.log('Sending message with config:', {
      baseURL: config.OPENROUTER_BASE_URL,
      model: config.OPENROUTER_MODEL,
      hasKey: !!config.OPENROUTER_API_KEY
    });

    setIsLoading(true);

    try {
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

      const response = await fetch(`${config.OPENROUTER_BASE_URL}/chat/completions`, {
        method: 'POST',
        headers: requestHeaders,
        body: JSON.stringify({
          model: config.OPENROUTER_MODEL,
          messages: [
            {
              role: 'system',
              content: `You are a helpful assistant for the CityPulse Dashboard - a city reporting system. You help users understand dashboard features, city reports, and provide general assistance. Keep responses concise, helpful, and use plain text without markdown formatting, headers, or special characters.`
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
