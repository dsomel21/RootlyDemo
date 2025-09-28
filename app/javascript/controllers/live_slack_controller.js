import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "avatar", "author", "text", "time"]
  static values = { 
    incidentId: String,
    state: String 
  }

  connect() {
    this.lastMessageTs = null
    this.currentMessage = null
    this.isVisible = true
    this.pollInterval = 8000 // Start with 8s
    this.maxPollInterval = 30000 // Cap at 30s
    this.lingerTime = 400000 // 400 seconds visible
    this.lingerTimer = null
    this.isHovered = false

    // Set up intersection observer for in-view detection
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          this.isVisible = entry.isIntersecting
          if (this.isVisible) {
            this.startPolling()
          } else {
            this.stopPolling()
          }
        })
      },
      { threshold: 0.1 }
    )
    this.observer.observe(this.element)

    // Set up hover listeners for pause/resume
    this.cardTarget.addEventListener('mouseenter', this.handleMouseEnter.bind(this))
    this.cardTarget.addEventListener('mouseleave', this.handleMouseLeave.bind(this))
    this.cardTarget.addEventListener('focus', this.handleMouseEnter.bind(this))
    this.cardTarget.addEventListener('blur', this.handleMouseLeave.bind(this))

    // Start initial polling if visible
    if (this.isVisible) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
    this.clearLingerTimer()
    this.observer?.disconnect()
  }

  startPolling() {
    if (this.pollTimer) return

    this.pollTimer = setInterval(() => {
      this.fetchLatestMessage()
    }, this.pollInterval)
    
    // Fetch immediately
    this.fetchLatestMessage()
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async fetchLatestMessage() {
    try {
      const response = await fetch(`/incidents/${this.incidentIdValue}/latest_message`)
      
      if (!response.ok) {
        // Silently skip on error - no UI spam
        return
      }

      const data = await response.json()
      
      // Check if this is a new message
      if (data.ts && data.ts !== this.lastMessageTs) {
        this.lastMessageTs = data.ts
        this.currentMessage = data
        this.showMessage(data)
        
        // Reset polling interval to 8s on new message
        this.pollInterval = 8000
        this.stopPolling()
        this.startPolling()
      }
    } catch (error) {
      // Silently skip on error - no UI spam
      console.debug('Live Slack: fetch error', error)
    }
  }

  showMessage(messageData) {
    // If we're already showing a message, queue this one
    if (this.stateValue === 'showing') {
      // For simplicity, replace current message with new one
      this.hideMessage()
      setTimeout(() => this.displayMessage(messageData), 100)
      return
    }

    this.displayMessage(messageData)
  }

  displayMessage(messageData) {
    // Populate the targets
    this.avatarTarget.src = messageData.avatar_url || ''
    this.avatarTarget.alt = messageData.author || 'User'
    this.authorTarget.textContent = messageData.author || 'Unknown'
    this.textTarget.textContent = messageData.text || ''
    this.timeTarget.textContent = this.formatRelativeTime(messageData.sent_at)

    // Make card visible and animate in
    this.cardTarget.classList.remove('invisible', 'opacity-0')
    this.cardTarget.classList.add('ls-anim-in')
    
    this.stateValue = 'showing'

    // Start linger timer
    this.startLingerTimer()

    // Add pulse after fade-in completes
    setTimeout(() => {
      this.cardTarget.classList.add('ls-anim-pulse')
    }, 320)
  }

  hideMessage() {
    this.cardTarget.classList.add('ls-anim-out')
    this.stateValue = 'hiding'

    // Wait for animation to complete, then hide
    setTimeout(() => {
      this.cardTarget.classList.add('invisible', 'opacity-0')
      this.cardTarget.classList.remove('ls-anim-in', 'ls-anim-pulse', 'ls-anim-out')
      this.stateValue = 'idle'
      this.clearLingerTimer()
    }, 260)
  }

  startLingerTimer() {
    this.clearLingerTimer()
    
    this.lingerTimer = setTimeout(() => {
      if (!this.isHovered) {
        this.hideMessage()
      }
    }, this.lingerTime)
  }

  clearLingerTimer() {
    if (this.lingerTimer) {
      clearTimeout(this.lingerTimer)
      this.lingerTimer = null
    }
  }

  handleMouseEnter() {
    this.isHovered = true
    this.clearLingerTimer()
  }

  handleMouseLeave() {
    this.isHovered = false
    if (this.stateValue === 'showing') {
      this.startLingerTimer()
    }
  }

  openMessage() {
    if (this.currentMessage?.permalink) {
      window.open(this.currentMessage.permalink, '_blank', 'noopener,noreferrer')
    }
  }

  formatRelativeTime(sentAt) {
    if (!sentAt) return 'just now'
    
    const now = new Date()
    const sent = new Date(sentAt)
    const diffMs = now - sent
    const diffSeconds = Math.floor(diffMs / 1000)
    const diffMinutes = Math.floor(diffSeconds / 60)
    const diffHours = Math.floor(diffMinutes / 60)

    if (diffSeconds < 60) return 'just now'
    if (diffMinutes < 60) return `${diffMinutes} min${diffMinutes === 1 ? '' : 's'} ago`
    if (diffHours < 24) return `${diffHours} hour${diffHours === 1 ? '' : 's'} ago`
    
    return sent.toLocaleDateString()
  }
}

