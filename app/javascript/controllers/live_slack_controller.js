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
    this.lingerTime = 8000 // 8 seconds visible
    this.initialDelay = 3000 // 3 seconds delay before starting to poll
    this.lingerTimer = null
    this.hasStartedPolling = false

    // TODO: Add Page Visibility API support - pause polling when tab is hidden
    // TODO: Add hover/focus interaction support - pause linger timer on hover
    
    // Set up intersection observer for in-view detection
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          this.isVisible = entry.isIntersecting
          
          if (this.isVisible) {
            this.scheduleInitialPolling()
          } else {
            this.stopPolling()
          }
        })
      },
      { threshold: 0.1 }
    )
    this.observer.observe(this.element)
    // Schedule initial polling with delay if visible
    if (this.isVisible) {
      this.scheduleInitialPolling()
    }
  }

  disconnect() {
    this.stopPolling()
    this.clearLingerTimer()
    this.observer?.disconnect()    
  }

  /**
   * Called by the intersection observer when the element becomes visible.
   * Waits 3 seconds before starting to poll to prevent disruptive notifications on page load.
   * Also handles restarting polling when coming back into view.
   */
  scheduleInitialPolling() {
    // If we haven't started polling yet, wait for initial delay
    if (!this.hasStartedPolling) {
      setTimeout(() => {
        if (this.isVisible) {
          this.startPolling(true) // Fetch immediately on first load
        }
      }, this.initialDelay)
    } else {
      // If we've already started polling before, restart without immediate fetch when coming back into view
      this.startPolling(false)
    }
  }

  /**
   * Called by scheduleInitialPolling() after 3s delay, or when resetting after new message.
   * Example walkthrough: User loads page → element visible → scheduleInitialPolling() → 
   * wait 3s → startPolling() → fetch immediately + set 8s interval → new message arrives → 
   * reset interval → startPolling() called again
   */
  startPolling(shouldFetchImmediately = false) {
    if (this.pollTimer) return

    this.hasStartedPolling = true

    this.pollTimer = setInterval(() => {
      this.fetchLatestMessage()
    }, this.pollInterval)
    
    // Only fetch immediately on first load, not when coming back into view
    if (shouldFetchImmediately) {
      this.fetchLatestMessage()
    }
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
        this.startPolling(false) // Don't fetch immediately when resetting
      }
    } catch (error) {
      // Silently skip on error - no UI spam
    }
  }

  showMessage(messageData) {
    // If we're already showing a message, replace it immediately
    if (this.stateValue === 'showing') {
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

    // Make card visible and animate in using BEM classes
    this.cardTarget.style.visibility = 'visible'
    this.cardTarget.style.opacity = '1'
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

    // Wait for animation to complete, then hide using BEM classes
    setTimeout(() => {
      this.cardTarget.style.visibility = 'hidden'
      this.cardTarget.style.opacity = '0'
      this.cardTarget.classList.remove('ls-anim-in', 'ls-anim-pulse', 'ls-anim-out')
      this.stateValue = 'idle'
      this.clearLingerTimer()
    }, 260)
  }

  startLingerTimer() {
    this.clearLingerTimer()
    
    this.lingerTimer = setTimeout(() => {
      this.hideMessage()
    }, this.lingerTime)
  }

  clearLingerTimer() {
    if (this.lingerTimer) {
      clearTimeout(this.lingerTimer)
      this.lingerTimer = null
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

