# main.py
import pygame
import json
import sys
import random
from boid import Boid
from slider import Slider

# Загрузка конфигурации
with open("C:\MyPythonProjects\Boids_Lab3\config.json", "r", encoding="utf-8") as f:
    config = json.load(f)

pygame.init()
screen = pygame.display.set_mode((config["window_width"], config["window_height"]))
pygame.display.set_caption("Лабораторная работа №3 — Бойды (165 шт)")
clock = pygame.time.Clock()
font = pygame.font.SysFont("segoeui", 20)

# Создание бойдов
boids = []
for _ in range(config["boid_count"]):
    x = random.randint(100, config["window_width"] - 100)
    y = random.randint(100, config["window_height"] - 100)
    boids.append(Boid(x, y, config))

# Слайдеры
sliders = [
    Slider(20, 20, 300, 0.0, 3.0, config["separation_weight"], "Separation weight"),
    Slider(20, 80, 300, 0.0, 3.0, config["alignment_weight"], "Alignment weight"),
    Slider(20, 140, 300, 0.0, 3.0, config["cohesion_weight"], "Cohesion weight"),
]

# Основной цикл
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

        # включение/выключение правил клавишами 1,2,3
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_1:
                config["separation_enabled"] = not config["separation_enabled"]
            if event.key == pygame.K_2:
                config["alignment_enabled"] = not config["alignment_enabled"]
            if event.key == pygame.K_3:
                config["cohesion_enabled"] = not config["cohesion_enabled"]

        for slider in sliders:
            slider.handle_event(event)

    # обновляем веса из слайдеров
    config["separation_weight"] = sliders[0].get_value()
    config["alignment_weight"] = sliders[1].get_value()
    config["cohesion_weight"] = sliders[2].get_value()

    # обновление бойдов
    for boid in boids:
        boid.update(boids)

    screen.fill(config["background_color"])  # отрисовка

    for boid in boids:
        boid.draw(screen)

    # UI
    for slider in sliders:
        slider.draw(screen, font)

    # подсказки
    hints = [
        "1 — Разделение (Separation): "
        + ("ВКЛ" if config["separation_enabled"] else "ВЫКЛ"),
        "2 — Выравнивание (Alignment): "
        + ("ВКЛ" if config["alignment_enabled"] else "ВЫКЛ"),
        "3 — Сплочённость (Cohesion): "
        + ("ВКЛ" if config["cohesion_enabled"] else "ВЫКЛ"),
        "Мышь — регулировка весов сил",
    ]
    for i, text in enumerate(hints):
        surf = font.render(text, True, (200, 255, 200))
        screen.blit(surf, (20, config["window_height"] - 120 + i * 25))

    pygame.display.flip()
    clock.tick(60)

pygame.quit()
sys.exit()
