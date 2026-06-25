# slider.py
import pygame

class Slider:
    def __init__(self, x, y, w, min_val, max_val, initial_val, title):
        self.rect = pygame.Rect(x, y, w, 20)
        self.min = min_val
        self.max = max_val
        self.value = initial_val
        self.title = title
        self.dragging = False

    def handle_event(self, event):
        if event.type == pygame.MOUSEBUTTONDOWN:
            if self.rect.collidepoint(event.pos):
                self.dragging = True
        elif event.type == pygame.MOUSEBUTTONUP:
            self.dragging = False
        elif event.type == pygame.MOUSEMOTION and self.dragging:
            x = max(self.rect.left, min(event.pos[0], self.rect.right))
            ratio = (x - self.rect.left) / self.rect.width
            self.value = self.min + ratio * (self.max - self.min)

    def get_value(self):
        return self.value

    def draw(self, screen, font):
        # фон слайдера
        pygame.draw.rect(screen, (50, 50, 50), self.rect)
        pygame.draw.rect(screen, (80, 80, 80), self.rect, 2)

        # ползунок
        ratio = (self.value - self.min) / (self.max - self.min)
        handle_x = self.rect.left + int(ratio * self.rect.width)
        pygame.draw.circle(screen, (200, 200, 255), (handle_x, self.rect.centery), 12)

        # подпись
        rus_titles = {
    "Separation weight": "Разделение:",
    "Alignment weight":  "Выравнивание:",
    "Cohesion weight":   "Сплочённость:"
        }
        title_ru = rus_titles.get(self.title, self.title)
        text = font.render(f"{title_ru} {self.value:.2f}", True, (255, 255, 255))
        screen.blit(text, (self.rect.x, self.rect.y - 25))
